# Chain — Future Plans

## Custom Terminal Support

**Goal**: Add a 6th "Custom" option to the terminal picker, letting users use any terminal app beyond the current 5 supported ones.

### How it works

1. User selects "Custom" in the Terminal picker
2. User picks any `.app` from their Mac via an app picker
3. User fills in one new field: the directory argument template, e.g.
   - kitty style: `--directory={DIR}`
   - alacritty style: `--working-directory {DIR}`
   - wezterm style: `start --cwd {DIR} --`
4. Chain automatically appends `/bin/sh -c "{CMD}"` and runs the binary

The existing **Command** field (e.g. `claude`) is substituted into `{CMD}` as usual.

### What needs to be built

- `ChainSupportedApp`: add a `custom` case (or a separate `CustomTerminalConfig` struct stored in UserDefaults)
- Settings UI: when "Custom" is selected, show
  - an app picker (NSOpenPanel filtered to `.app` bundles)
  - a text field for the directory arg template
- `runViaCLI`: handle the custom case by substituting `{DIR}` and running the binary found inside the selected `.app`

### Trade-offs

- Target audience: technical users who know their terminal's CLI flags
- Ordinary users may be confused by the directory arg template field
- Could mitigate by shipping a few preset templates the user can copy from
