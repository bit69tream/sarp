# SARP
**S**elect **A** **R**egion in a **P**icture

# Building
```sh
$ odin build . -o:speed
```

## Note for Wayland users
As of October 2025 the Odin programming language ships with Raylib compiled
only with X11 support. To get the Wayland support you need to build Raylib with
Wayland enabled and replace the library files in your Odin installation.
After that everything should work smoothly.

Or you can just use XWayland :)

# Usage
```sh
$ sarp --help
SARP - Select a region in a picture
The tool spawns a window in which you can select a region. Once
you do that - the selected region will be printed to the STDOUT
in a specified format.
Arguments: sarp [parameters] <filepath>
Parameters:
  --help       Print this
  --format XXX Specity output format.
    Available format specifiers:
      %w - width
      %h - height
      %x - x coordinate from the top left
      %y - y coordinate from the top left
    Default format: "%wx%h+%x+%y"
Usage:
  Hold LMB and drag it to select a region. Once you let go of the button the
  window will close and the region will be printed out to STDOUT.
  If you wish to cancel selection - press RMB and you can start selection again
  after you start holding the LMB again.
  To quit without selecting anything press either ESCAPE or Q.

$ sarp pic.png
69x420+100+0
```
