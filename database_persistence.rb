require 'pg'
require 'pry'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
        PG.connect(ENV['DATABASE_URL'])
      else
        PG.connect(dbname: "todos")
      end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1"
    sql_todos = "SELECT id, name, completed FROM todo WHERE list_id = $1"
    result = query(sql, id)
    todo_result = query(sql_todos, id)
    tuple = result.first
    todos = get_todos(todo_result)
    {id: tuple["id"].to_i, name: tuple["name"], todos: todos}
  end

  def all_lists
    sql = "SELECT * FROM lists"
    result = query(sql)
    result.map do |tuple|
      list_id = tuple["id"].to_i
      sql_todos = "SELECT id, name, completed FROM todo WHERE list_id = $1"
      todo_result = query(sql_todos, list_id)
      todos = get_todos(todo_result)

      {id: list_id, name: tuple["name"], todos: todos}
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(id)
    query("DELETE FROM todo WHERE list_id = $1", id)
    query("DELETE FROM lists WHERE id = $1", id)
  end

  def update_list_name(id, new_list_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_list_name, id)
  end

  def create_new_todo(list_id, new_todo_name)
    sql = "INSERT INTO todo (name, list_id) VALUES ($1, $2)"
    query(sql, new_todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    query("DELETE FROM todo WHERE list_id = $1 AND id = $2", list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, is_completed)
    sql = "UPDATE todo SET completed = $1 WHERE list_id = $2 AND id = $3"
    query(sql, is_completed, list_id, todo_id)
  end

  def complete_all_todos(list_id)
    sql = "UPDATE todo SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  private

  def get_todos(result)
    result.map do |tuple|
      {id: tuple["id"].to_i,
      name: tuple["name"],
      completed: tuple["completed"] == "t"}
    end
  end
end
