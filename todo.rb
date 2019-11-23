require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# GET /lists => view all lists
# GET /lists/new => new list form
# POST /lists => create new list
# GET /lists/1 => view a single list

# resource type + ID of whatever the object is

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Update an existing to do list.
post "/lists/:id" do
  new_list_name = params[:list_name].strip
  @list = session[:lists][params[:id].to_i]

  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error
    erb :edit_list_name, layout: :layout
  else
    @list[:name] = new_list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{params[:id]}"
  end
end

# render the edit list_name form

get "/lists/:id/edit" do
  @list = session[:lists][params[:id].to_i]
  erb :edit_list_name, layout: :layout
end

# delete a list, render back to the all list page
# here, we should probably render a "your list has been successfully deleted" page.
post "/lists/:id/destroy" do
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# you're basically just trying to update a hash. but how to get correct index?

# Return an error message if the name is invalid

def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? {|list| list[:name] == name}
    "List name must be unique."
  end
end

# Return an error message if the todo name is invalid

def error_for_todo_name(name, idx)
  if !(1..100).cover? name.size
    "Todo name must be between 1 and 100 characters."
  elsif session[:lists][idx][:todos].any? {|todo| todo == name}
    "Todo name must be unique."
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
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:id" do
  @list = session[:lists][params[:id].to_i]
  erb :single_todo, layout: :layout
end

# Create a new todo item

post "/lists/:list_id/todos" do
  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name,params[:list_id].to_i)
  if error
    session[:error] = error
    erb :single_todo, layout: :layout
  else
    session[:lists][params[:list_id].to_i][:todos] << {name: todo_name, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{params[:list_id]}"
  end
end
