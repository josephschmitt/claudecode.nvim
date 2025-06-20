-- luacheck: globals expect
require("tests.busted_setup")

describe("snacks.nvim integration", function()
  local integrations
  local mock_vim

  local function setup_mocks()
    package.loaded["claudecode.integrations"] = nil
    package.loaded["claudecode.visual_commands"] = nil
    package.loaded["claudecode.logger"] = nil

    -- Mock logger
    package.loaded["claudecode.logger"] = {
      debug = function() end,
      warn = function() end,
      error = function() end,
    }

    mock_vim = {
      fn = {
        mode = function()
          return "n" -- Default to normal mode
        end,
        line = function(mark)
          if mark == "'<" then
            return 2
          elseif mark == "'>" then
            return 4
          end
          return 1
        end,
        fnamemodify = function(path, modifier)
          if modifier == ":t" then
            return path:match("([^/]+)$") or path
          end
          return path
        end,
      },
      api = {
        nvim_get_current_buf = function()
          return 1
        end,
        nvim_win_get_cursor = function()
          return { 4, 0 }
        end,
        nvim_get_mode = function()
          return { mode = "n" }
        end,
      },
      bo = { filetype = "snacks_layout_box" },
    }

    _G.vim = mock_vim
  end

  before_each(function()
    setup_mocks()
    integrations = require("claudecode.integrations")
  end)

  after_each(function()
    package.loaded["claudecode.integrations"] = nil
    package.loaded["claudecode.visual_commands"] = nil
    package.loaded["claudecode.logger"] = nil
    package.loaded["snacks"] = nil
    _G.vim = nil
  end)

  describe("get_selected_files_from_tree", function()
    it("should detect snacks_layout_box filetype", function()
      -- Mock snacks module
      package.loaded["snacks"] = {
        picker = {
          get = function()
            return {
              current = function()
                return { file = "/test/path/test.lua" }
              end,
              dir = function()
                return "/test/path/"
              end,
              get_item = function(line)
                return { file = "/test/path/test" .. line .. ".lua" }
              end
            }
          end
        }
      }

      local files, error = integrations.get_selected_files_from_tree()

      expect(error).to.be.nil()
      expect(files).to.be.a("table")
      expect(#files).to.equal(1)
      expect(files[1]).to.equal("/test/path/test.lua")
    end)

    it("should handle missing snacks module", function()
      package.loaded["snacks"] = nil

      local files, error = integrations.get_selected_files_from_tree()

      expect(files).to.be.a("table")
      expect(#files).to.equal(0)
      expect(error).to.equal("snacks file explorer not available")
    end)

    it("should handle missing picker instance", function()
      package.loaded["snacks"] = {
        picker = {
          get = function()
            return nil
          end
        }
      }

      local files, error = integrations.get_selected_files_from_tree()

      expect(files).to.be.a("table")
      expect(#files).to.equal(0)
      expect(error).to.equal("No active snacks picker found")
    end)

    it("should skip parent directory entries", function()
      package.loaded["snacks"] = {
        picker = {
          get = function()
            return {
              current = function()
                return { file = "/test/path/.." }
              end,
              dir = function()
                return "/test/path/"
              end
            }
          end
        }
      }

      local files, error = integrations.get_selected_files_from_tree()

      expect(files).to.be.a("table")
      expect(#files).to.equal(0)
      expect(error).to.equal("No file found under cursor")
    end)
  end)
end)