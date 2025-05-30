# nest-repl.nvim

A Neovim plugin to load methods from TypeScript/JavaScript classes into the NestJS REPL.

## Features

- Dedicated terminal split for NestJS REPL (configurable position)
- Load selected methods from TypeScript/JavaScript classes into REPL
- Load methods into variables for further use
- Supports async methods with automatic await
- Simple command interface
- Convenient keybindings
- Smart method detection

## Installation


Setup your project, as explained on the [NestJS Docs](https://docs.nestjs.com/recipes/repl), to integrate with repl.


Add the plugin using your package manager of choice.

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use 'nandoolle/nest-repl.nvim'
```
Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'nandoolle/nest-repl.nvim',
  lazy = true,
  ft = { 'typescript', 'javascript' },
  cond = function()
    return require('nest-repl.detect').is_nest_project()
  end,
  config = function()
    require('nest-repl').setup({
      -- recommended command `npm run start -- --watch --entryFile repl`
      repl_command = 'npm run start -- --watch --entryFile repl',
      terminal_width = 80, -- Width of the terminal split
      terminal_position = 'right', -- 'left' or 'right'
    })
  end,
}
```

## Configuration

```lua
require('nest-repl').setup({
  repl_command = 'npm run start -- --watch --entryFile repl', -- Command to start NestJS REPL
  terminal_width = 80,            -- Width of the terminal split
  terminal_position = 'right',    -- Position of the terminal ('left' or 'right')
  keybindings = {                 -- Customize keybindings
    start_repl = "<localleader>snr",    -- Start NestJS REPL
    load_method = "<localleader>em",    -- Load method to REPL
    load_method_to_var = "<localleader>etv" -- Load method to variable
  }
})
```

## Default Keybindings

The plugin provides the following default keybindings:

- `<localleader>snr` - Start NestJS REPL
- `<localleader>em` - Load selected method to REPL (in normal or visual mode)
- `<localleader>etv` - Load selected method to variable (in normal or visual mode)

You can customize these keybindings in the setup configuration. For example:

```lua
require('nest-repl').setup({
  keybindings = {
    start_repl = "<leader>nr",        -- Change to <leader>nr
    load_method = "<leader>lm",       -- Change to <leader>lm
    load_method_to_var = "<leader>lv" -- Change to <leader>lv
  }
})
```

If no keybindings are provided in the setup options, the plugin will use the default keybindings.

## Usage

1. Start the REPL with `:NestReplStart` or `<localleader>nrs`

   - This opens a terminal split (default: right side)
   - The REPL will be ready to accept commands
   - Use `<C-w>q` in terminal mode to close the REPL terminal

2. To execute a method, you have two options:

   a. Using visual selection:

   - Open a TypeScript/JavaScript file containing a class
   - Select a method in visual mode (press `v` and select the method)
   - Run the command `:NestReplLoad` or use `<localleader>em`

   b. Using cursor position:

   - Place your cursor anywhere inside a method
   - Press `<localleader>nrl` in normal mode
   - The entire method will be automatically detected and loaded

   The method will be executed in the REPL terminal and you can see the output directly in the terminal.

3. To load a method into a variable:

   a. Using visual selection:

   - Select a method in visual mode
   - Press `<localleader>etv`
   - The method will be loaded into a variable named after the method

   b. Using cursor position:

   - Place your cursor anywhere inside a method
   - Press `<localleader>etv` in normal mode
   - The method will be loaded into a variable named after the method

   Example: If you have a method named `getUser`, it will be loaded as:

   ```typescript
   let getUser = await $(YourClass).getUser();
   ```

## Requirements

- Neovim 0.7.0 or higher
- NestJS CLI installed globally or locally in your project

## License

MIT
