--# selene:allow(incorrect_standard_library_use)
local Task = require("lazy.manage.task")

describe("task", function()
  local plugin = { name = "test", _ = {} }

  ---@type {done?:boolean, error:string?}
  local task_result = {}

  local opts = {
    ---@param task LazyTask
    on_done = function(task)
      task_result = { done = true, error = task.error }
    end,
  }

  before_each(function()
    task_result = {}
  end)

  it("simple function", function()
    local task = Task.new(plugin, "test", function() end, opts)
    assert(not task:has_started())
    assert(not task:is_running())
    task:start()
    task:wait()
    assert(not task:is_running())
    assert(task:is_done())
    assert(task_result.done)
  end)

  it("detects errors", function()
    local task = Task.new(plugin, "test", function()
      error("test")
    end, opts)
    assert(not task:has_started())
    assert(not task:is_running())
    task:start()
    task:wait()
    assert(task:is_done())
    assert(not task:is_running())
    assert(task_result.done)
    assert(task_result.error)
    assert(task.error and task.error:find("test"))
  end)

  it("async", function()
    local running = true
    local task = Task.new(plugin, "test", function(task)
      task:async(function()
        coroutine.yield()
        running = false
      end)
    end, opts)
    assert(not task:is_running())
    assert(not task:has_started())
    task:start()
    assert(running)
    assert(task:is_running())
    assert(not task:is_done())
    task:wait()
    assert(not running)
    assert(task:is_done())
    assert(not task:is_running())
    assert(task_result.done)
    assert(not task.error)
  end)

  it("spawn errors", function()
    local task = Task.new(plugin, "spawn_errors", function(task)
      task:spawn("foobar")
    end, opts)
    assert(not task:is_running())
    task:start()
    task:wait()
    assert(not task:is_running())
    assert(task_result.done)
    assert(task.error and task.error:find("Failed to spawn"), task.output)
  end)

  it("spawn", function()
    local task = Task.new(plugin, "test", function(task)
      task:spawn("echo", { args = { "foo" } })
    end, opts)
    assert(not task:is_running())
    assert(not task:has_started())
    task:start()
    assert(task:has_started())
    assert(task:is_running())
    task:wait()
    assert(task:is_done())
    assert.same(task.output, "foo\n")
    assert(task_result.done)
    assert(not task.error)
  end)

  it("spawn 2x", function()
    local task = Task.new(plugin, "test", function(task)
      task:spawn("echo", { args = { "foo" } })
      task:spawn("echo", { args = { "bar" } })
    end, opts)
    assert(not task:is_running())
    task:start()
    assert(task:is_running())
    task:wait()
    assert(task.output == "foo\nbar\n" or task.output == "bar\nfoo\n", task.output)
    assert(task_result.done)
    assert(not task.error)
  end)
end)
