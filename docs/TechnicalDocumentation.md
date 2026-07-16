# TODO


## Compilation of addon
This repository uses template for developing [GDExtensions](https://docs.godotengine.org/en/stable/classes/class_gdextension.html) in C++ for [Godot Engine](https://godotengine.org/).

The installation step will be 
## Requirements
- [GitHub](https://github.com/) account because we are going to be using GitHub Actions for cross platform compilation
- [Git](https://git-scm.com/downloads) installed on your machine and configured correctly so you can push changes to remote
- [Python](https://www.python.org/) latest version and ensure it's available in <b>system environment PATH</b>
- [Scons](https://scons.org/) latest version and ensure it's available in <b>system environment PATH</b>
    - Windows command: `pip install scons`
    - macOS command: `python3 -m pip install scons`
    - Linux command `python3 -m pip install scons`
- C++ compiler
    - Windows: MSVC (Microsoft Visual C++) via Visual Studio or Build Tools.
    - macOS: Clang (included with Xcode or Xcode Command Line Tools).
    - Linux: GCC or Clang (available via package managers).
- [Visual Studio Code](https://code.visualstudio.com/) or any other editor that supports C++ and the `compile_commands.json`

Here are some include directories, if you are stubbornly choosing not to use compile_commands.json or if for some reason your editor needs it for extra features (Visual Studio Code will NOT need it as long as we use the Clangd extension)
```
${workspaceFolder}/godot-cpp/gdextension/
${workspaceFolder}/godot-cpp/gen/**
${workspaceFolder}/godot-cpp/include/**
${workspaceFolder}/godot-cpp/src/**

${workspaceFolder}/src   -> usually where you write all your code  
```




## How to use

You can choose to watch this tutorial for beginners - https://www.youtube.com/watch?v=I79u5KNl34o
##
