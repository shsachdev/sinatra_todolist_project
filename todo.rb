require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

configure do
  set :erb, :escape_html => true
end

class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists][id] if index && session[:lists][id]
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    id = next_element_id(@session[:lists])
    @session[:lists] << {id: id, name: list_name, todos: []}
  end

  def delete_list(id)
    @session[:lists].delete_at(id)
  end

  def update_list_name(id, new_list_name)
    list = find_list(id)
    list[:name] = new_list_name
  end

  def create_new_todo(list_id, new_todo_name)
    list = find_list(list_id)
    id = next_element_id(list[:todos])
    list[:todos] << {id: id, name: new_todo_name, completed: false}
  end

  def delete_todo_from_list(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, is_completed)
    list = find_list(list_id)
    todo = list[:todos].find {|t| t[:id] == todo_id}
    todo[:completed] = is_completed
  end

  private

  def next_element_id(elements)
    max = elements.map {|todo| todo[:id]}.max || 0
    max + 1
  end
end

def load_list(index)
  list = @storage.find_list(id)
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_remaining_count(list)
    list[:todos].select {|todo| !todo[:completed]}.size
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    incomplete_lists = {}
    complete_lists = {}

    lists.each_with_index do |list, index|
      if list_complete?(list)
        complete_lists[list] = index
      else
        incomplete_lists[list] = index
      end
    end

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

before do
  @storage = SessionPersistence.new(session)
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Update an existing to do list.
post "/lists/:id" do
  new_list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error
    erb :edit_list_name, layout: :layout
  else
    @storage.update_list_name(id, new_list_name)
    session[:success] = "The list has been updated."
    redirect "/lists/#{params[:id]}"
  end
end

# render the edit list_name form

get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list_name, layout: :layout
end

# delete a list, render back to the all list page
# here, we should probably render a "your list has been successfully deleted" page.
post "/lists/:id/destroy" do
  id = params[:id].to_i
  @storage.delete_list(id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# you're basically just trying to update a hash. but how to get correct index?

# Return an error message if the name is invalid

def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif @storage.all_lists.any? {|list| list[:name] == name}
    "List name must be unique."
  end
end

# Return an error message if the todo name is invalid

def error_for_todo_name(name)
  if !(1..100).cover? name.size
    "Todo name must be between 1 and 100 characters."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a single todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :single_todo, layout: :layout
end

def next_todo_id(todos)
  max = todos.map {|todo| todo[:id]}.max || 0
  max + 1
end

# Create a new todo item
post "/lists/:list_id/todos" do
  todo_name = params[:todo].strip
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  error = error_for_todo_name(todo_name)
  if error
    session[:error] = error
    erb :single_todo, layout: :layout
  else
    @storage.create_new_todo(@list_id, todo_name)
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list

post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @storage.delete_todo_from_list(@list_id, todo_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todos

post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"

  @storage.update_todo_status(@list_id, todo_id, is_completed)

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as completed

post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end
