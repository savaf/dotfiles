# VS Code Settings

# Font

* [Anonymous Pro](https://www.marksimonson.com/fonts/view/anonymous-pro)

## Themes/Color

* [Just Black](https://marketplace.visualstudio.com/items?itemName=nur.just-black)
  * See [`editor.tokenColorCustomizations`](#settings) in my VS Code settings for a few modifications I make to the theme.

## Extensions

* Theme / Editor Experience
  * [FontSize ShortCuts](https://marketplace.visualstudio.com/items?itemName=fosshaas.fontsize-shortcuts)
    * Change the font size with keyboard shortcuts.
  * [vscode-icons](https://marketplace.visualstudio.com/items?itemName=vscode-icons-team.vscode-icons)
    * Nice / colorful icons for many different file types
  * [ESLint](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint)
    * Integrates ESLint JS
  * [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
    * Automatically format javascript, JSON, CSS, Sass
  * [PostCSS Intellisense and Highlighting](https://marketplace.visualstudio.com/items?itemName=vunguyentuan.vscode-postcss)
    * Works better than the other more popular one of a similar name.
  * [Code Spell Checker](https://marketplace.visualstudio.com/items?itemName=streetsidesoftware.code-spell-checker)
    * Spell check markdown, comments and variable names.
  * [Pretty TypeScript Errors](https://marketplace.visualstudio.com/items?itemName=yoavbls.pretty-ts-errors)
    * Makes TS errors more human readable.
* Useful Tools
  * [Paste JSON as Code](https://marketplace.visualstudio.com/items?itemName=quicktype.quicktype)
    * Auto generate TypeScript (and other languages) types from JSON data.
  * [Code Snap](https://marketplace.visualstudio.com/items?itemName=adpyke.codesnap)
    * Take pictures of code with your VS Code Theme / Font settings.
  * [Thunder Client](https://marketplace.visualstudio.com/items?itemName=rangav.vscode-thunder-client)
    * Make HTTP requests from inside VS Code (similar to Postman / Insomnia).
* Languages and Libraries
  * [XML Tools](https://marketplace.visualstudio.com/items?itemName=DotJoshJohnson.xml)
    * XML Formatting, XQuery, and XPath Tools for Visual Studio Code.
  * [Tailwind CSS IntelliSense](https://marketplace.visualstudio.com/items?itemName=bradlc.vscode-tailwindcss)
    * Intelligent Tailwind CSS tooling for VS Code.
  * React
    * [ES7+ React/Redux/React-Native snippets](https://marketplace.visualstudio.com/items?itemName=dsznajder.es7-react-js-snippets)
      * Extensions for React, React-Native and Redux in JS/TS with ES7+ syntax. Customizable. Built-in integration with prettier.
    * [CSS to JSS](https://marketplace.visualstudio.com/items?itemName=infarkt.css-to-jss)
      * Convert CSS to JSS
    * [CSS in JS](https://marketplace.visualstudio.com/items?itemName=paulmolluzzo.convert-css-in-js)
      * Get syntax highlighting when working with CSS in JS template strings.
    * [vscode-styled-components](https://marketplace.visualstudio.com/items?itemName=styled-components.vscode-styled-components)
      * Syntax highlighting for styled-components.
  * [Volar](https://marketplace.visualstudio.com/items?itemName=Vue.volar)
    * Language support for Vue 3
  * [Svelte for VS Code](https://marketplace.visualstudio.com/items?itemName=svelte.svelte-vscode)
    * Svelte language support for VS Code.
  * [Prisma](https://marketplace.visualstudio.com/items?itemName=Prisma.prisma)
    * Adds syntax highlighting, formatting, auto-completion, jump-to-definition and linting for .prisma files.
  * [htmx-tags](https://marketplace.visualstudio.com/items?itemName=otovo-oss.htmx-tags)
    * Provides HTMX tag completion in HTML files in VSCode
  * [Markdown Mermaid Preview](https://marketplace.visualstudio.com/items?itemName=bierner.markdown-mermaid)
    * View Mermaid diagrams when previewing Markdown.

### Extension package names for easy install

```
Extensions installed on WSL: Ubuntu:
aaron-bond.better-comments
amphtml.amphtml-validator
antfu.iconify
aykutsarac.jsoncrack-vscode
bradlc.vscode-tailwindcss
christian-kohler.npm-intellisense
christian-kohler.path-intellisense
dbaeumer.vscode-eslint
deerawan.vscode-faker
eamodio.gitlens
editorconfig.editorconfig
emmanuelbeziat.vscode-great-icons
esbenp.prettier-vscode
fib.beautyamp
fosshaas.fontsize-shortcuts
gamunu.vscode-yarn
github.copilot
github.copilot-chat
github.vscode-github-actions
jock.svg
kisstkondoros.vscode-codemetrics
kisstkondoros.vscode-gutter-preview
mikestead.dotenv
ms-azuretools.vscode-docker
ms-dotnettools.vscode-dotnet-runtime
ms-vscode.vscode-typescript-next
ms-vsliveshare.vsliveshare
nuxt.mdc
prisma.prisma
redhat.vscode-yaml
rvest.vs-code-prettier-eslint
snappify.snappify
streetsidesoftware.code-spell-checker
streetsidesoftware.code-spell-checker-spanish
tamasfe.even-better-toml
teabyii.ayu
unifiedjs.vscode-mdx
usernamehw.errorlens
vue.volar
waifuproject.icns-preview
wix.vscode-import-cost
xnerd.ampscript-language
yoavbls.pretty-ts-errors
yzhang.markdown-all-in-one
```

# Settings

```json
{
  "files.trimTrailingWhitespace": true,
  "diffEditor.ignoreTrimWhitespace": false,
  "editor.detectIndentation": true,
  "editor.fontFamily": "\"MonaspiceAr Nerd Font\", \"Monaspace Argon SemiWide\", \"Fira Code\", \"Courier New\", monospace",
  "editor.fontWeight": "500",
  "editor.fontLigatures": true,
  "editor.fontSize": 16,
  "editor.formatOnPaste": false,
  "editor.inlineSuggest.enabled": true,
  "editor.lineHeight": 0,
  "editor.linkedEditing": true,
  "editor.minimap.enabled": false,
  "editor.multiCursorModifier": "ctrlCmd",
  "editor.snippetSuggestions": "top",
  "editor.suggestSelection": "first",
  "editor.tabSize": 2,
  "editor.indentSize": "tabSize",
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": true,
  "editor.guides.highlightActiveIndentation": true,
  "editor.guides.bracketPairsHorizontal": "active",
  "editor.tokenColorCustomizations": {
    "textMateRules": [
      {
        "scope": ["keyword.operator", "punctuation.separator"],
        "settings": {
          "fontStyle": ""
        }
      },
      {
        "scope": ["comment", "comment.block"],
        "settings": {
          "fontStyle": "italic",
          "foreground": "#F5F"
        }
      },
      {
        "name": "envKeys",
        "scope": "string.quoted.double.env,source.env,constant.numeric.env",
        "settings": {
          "foreground": "#19354900"
        }
      }
    ]
  },
  "editor.unicodeHighlight.invisibleCharacters": false,
  "emmet.showAbbreviationSuggestions": false,
  "eslint.enable": true,
  "eslint.validate": ["vue", "react", "typescript", "html", "javascript"],
  "explorer.openEditors.visible": 1,
  "extensions.ignoreRecommendations": true,
  "files.autoSave": "onWindowChange",
  "git.autofetch": true,
  "git.openRepositoryInParentFolders": "never",
  "markdown.preview.fontSize": 36,
  "screencastMode.keyboardOptions": {
    "showCommandGroups": false,
    "showCommands": false,
    "showKeybindings": true,
    "showKeys": false,
    "showSingleEditorCursorMoves": true
  },
  "search.exclude": {
    "**/*.code-search": true,
    "**/bower_components": true,
    "**/node_modules": true
  },
  "search.useIgnoreFiles": false,
  "terminal.integrated.fontSize": 14,
  "window.zoomLevel": 1,
  "workbench.colorTheme": "Ayu Dark",
  "workbench.editor.labelFormat": "medium",
  "workbench.editor.showTabs": "multiple",
  "workbench.iconTheme": "vscode-great-icons",
  "workbench.sideBar.location": "right",
  "workbench.startupEditor": "newUntitledFile",
  "workbench.statusBar.visible": true,
  "workbench.colorCustomizations": {
    "[Panda Syntax]": {
      "editorBracketHighlight.foreground1": "#E6E6E6",
      "editorBracketHighlight.foreground2": "#FF75B5",
      "editorBracketHighlight.foreground3": "#19f9d8",
      "editorBracketHighlight.foreground4": "#B084EB",
      "editorBracketHighlight.foreground5": "#45A9F9",
      "editorBracketHighlight.foreground6": "#FFB86C",
      "editorBracketHighlight.unexpectedBracket.foreground": "#FF2C6D",

      "editorBracketPairGuide.background1": "#FFB86C",
      "editorBracketPairGuide.background2": "#FF75B5",
      "editorBracketPairGuide.background3": "#45A9F9",
      "editorBracketPairGuide.background4": "#B084EB",
      "editorBracketPairGuide.background5": "#E6E6E6",
      "editorBracketPairGuide.background6": "#19f9d8",

      "editorBracketPairGuide.activeBackground1": "#FFB86C",
      "editorBracketPairGuide.activeBackground2": "#FF75B5",
      "editorBracketPairGuide.activeBackground3": "#45A9F9",
      "editorBracketPairGuide.activeBackground4": "#B084EB",
      "editorBracketPairGuide.activeBackground5": "#E6E6E6",
      "editorBracketPairGuide.activeBackground6": "#19f9d8"
    }
  },
  "[css]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[handlebars]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[html]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[javascriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[jsonc]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[markdown]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "files.trimTrailingWhitespace": false
  },
  "[scss]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[vue]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[svg]": {
    "editor.defaultFormatter": "jock.svg"
  },
  "[amp]": {
    "editor.defaultFormatter": "FiB.beautyAmp"
  },
  "html.autoClosingTags": true,
  "javascript.autoClosingTags": true,
  "typescript.autoClosingTags": true,
  "javascript.preferences.renameMatchingJsxTags" : true,
  "typescript.preferences.renameMatchingJsxTags" : true,
  "cSpell.enabled": true,
  "cSpell.userWords": [
    "acumatica",
    "baka",
    "barcode",
    "bigint",
    "composables",
    "corotos",
    "customely",
    "dansek",
    "headlessui",
    "heroicons",
    "icon",
    "initialize",
    "intras",
    "Klassy",
    "letsbld",
    "memod",
    "Memod",
    "middlewares",
    "mixins",
    "nuxt",
    "nuxtjs",
    "nzxt",
    "pcpartpicker",
    "phalcon",
    "Pinia",
    "prebuild",
    "Quisquella",
    "shopify",
    "smallint",
    "splash",
    "spock",
    "STRAPI",
    "supabase",
    "tailwindcss",
    "tinyint",
    "trpc",
    "tsup",
    "typecheck",
    "typeorm",
    "uniqid",
    "varchar"
  ],
}
```

# Keybindings

```json
[
  {
    "key": "cmd+1",
    "command": "workbench.action.openEditorAtIndex1"
  },
  {
    "key": "ctrl+1",
    "command": "-workbench.action.openEditorAtIndex1"
  },
  {
    "key": "cmd+2",
    "command": "workbench.action.openEditorAtIndex2"
  },
  {
    "key": "ctrl+2",
    "command": "-workbench.action.openEditorAtIndex2"
  },
  {
    "key": "cmd+3",
    "command": "workbench.action.openEditorAtIndex3"
  },
  {
    "key": "ctrl+3",
    "command": "-workbench.action.openEditorAtIndex3"
  },
  {
    "key": "cmd+4",
    "command": "workbench.action.openEditorAtIndex4"
  },
  {
    "key": "ctrl+4",
    "command": "-workbench.action.openEditorAtIndex4"
  },
  {
    "key": "cmd+5",
    "command": "workbench.action.openEditorAtIndex5"
  },
  {
    "key": "ctrl+5",
    "command": "-workbench.action.openEditorAtIndex5"
  },
  {
    "key": "cmd+6",
    "command": "workbench.action.openEditorAtIndex6"
  },
  {
    "key": "ctrl+6",
    "command": "-workbench.action.openEditorAtIndex6"
  },
  {
    "key": "cmd+7",
    "command": "workbench.action.openEditorAtIndex7"
  },
  {
    "key": "ctrl+7",
    "command": "-workbench.action.openEditorAtIndex7"
  },
  {
    "key": "cmd+8",
    "command": "workbench.action.openEditorAtIndex8"
  },
  {
    "key": "ctrl+8",
    "command": "-workbench.action.openEditorAtIndex8"
  },
  {
    "key": "cmd+9",
    "command": "workbench.action.openEditorAtIndex9"
  },
  {
    "key": "ctrl+9",
    "command": "-workbench.action.openEditorAtIndex9"
  },
  {
    "key": "ctrl+1",
    "command": "workbench.action.focusFirstEditorGroup"
  },
  {
    "key": "cmd+1",
    "command": "-workbench.action.focusFirstEditorGroup"
  },
  {
    "key": "ctrl+3",
    "command": "workbench.action.focusThirdEditorGroup"
  },
  {
    "key": "cmd+3",
    "command": "-workbench.action.focusThirdEditorGroup"
  },
  {
    "key": "ctrl+6",
    "command": "workbench.action.focusSixthEditorGroup"
  },
  {
    "key": "cmd+6",
    "command": "-workbench.action.focusSixthEditorGroup"
  },
  {
    "key": "ctrl+7",
    "command": "workbench.action.focusSeventhEditorGroup"
  },
  {
    "key": "cmd+7",
    "command": "-workbench.action.focusSeventhEditorGroup"
  },
  {
    "key": "ctrl+2",
    "command": "workbench.action.focusSecondEditorGroup"
  },
  {
    "key": "cmd+2",
    "command": "-workbench.action.focusSecondEditorGroup"
  },
  {
    "key": "ctrl+4",
    "command": "workbench.action.focusFourthEditorGroup"
  },
  {
    "key": "cmd+4",
    "command": "-workbench.action.focusFourthEditorGroup"
  },
  {
    "key": "ctrl+5",
    "command": "workbench.action.focusFifthEditorGroup"
  },
  {
    "key": "cmd+5",
    "command": "-workbench.action.focusFifthEditorGroup"
  },
  {
    "key": "ctrl+8",
    "command": "workbench.action.focusEighthEditorGroup"
  },
  {
    "key": "cmd+8",
    "command": "-workbench.action.focusEighthEditorGroup"
  }
]
```