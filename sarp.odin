package sarp

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import r "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

handleArgs := proc() -> (filepath: string, outputFormat: string) {
  args := os.args[1:]
  if len(args) == 0 {
    fmt.fprintln(os.stderr, "sarp [parameters] <filepath>")
    os.exit(1)
  }

  outputFormat = "%wx%h+%x+%y"

  for len(args) > 0 {
    switch args[0] {
    case "--help":
      fmt.fprintln(
        os.stderr,
        "SARP - Select a region in a picture\n",
        "The tool spawns a window in which you can select a region.\n",
        "Once you do that - the selected region will be printed to the STDOUT in a specified format.\n",
        "Arguments: sarp [parameters] <filepath>\n",
        "Parameters:\n",
        "  --help       Print this\n",
        "  --format XXX Specity output format.\n",
        "    Available format specifiers:\n",
        "      %w - width\n",
        "      %h - height\n",
        "      %x - x coordinate from the top left\n",
        "      %y - y coordinate from the top left\n",
        "    Default format: '%wx%h+%x+%y'\n",
        "Usage:\n",
        "  Hold LMB and drag it to select a region. Once you let go of the button the\n",
        "  window will close and the region will be printed out to STDOUT.\n",
        "  If you wish to cancel selection - press RMB and you can start selection again\n",
        "  after you start holding the LMB again.\n",
        "  You can also hold the middle button to move the image around.\n",
        "  To quit without selecting anything press either ESCAPE or Q.",
      )
      os.exit(1)
    case "--format":
      if len(args) < 2 {
        fmt.fprintln(os.stderr, "Error: the format is not specified.")
        os.exit(1)
      }
      outputFormat = args[1]
      args = args[2:]
    case:
      if filepath != "" {
        fmt.fprintln(os.stderr, "Error: the filepath is specified more than once.")
        os.exit(1)
      }
      filepath = args[0]
      args = args[1:]
    }
  }

  if filepath == "" {
    fmt.fprintln(os.stderr, "Error: the filepath is not specified.")
    os.exit(1)
  }

  return
}

clampRect :: proc (a: r.Rectangle, screenSize: r.Vector2) -> (res: r.Rectangle) {
  res = a
  res.x = math.max(0, res.x)
  res.y = math.max(0, res.y)
  res.width = math.min(screenSize.x, res.width)
  res.height = math.min(screenSize.y, res.height)

  return res
}

fixRect :: proc(a: r.Rectangle) -> (b: r.Rectangle) {
  b = a
  if b.width < 0 {
    b.x += b.width
    b.width *= -1
  }
  if b.height < 0 {
    b.y += b.height
    b.height *= -1
  }

  return
}

SelectionState :: enum {
  None,
  InProcess,
  Aborted,
}

main :: proc() {
  r.SetTraceLogLevel(.ERROR)
  filepath, outputFormat := handleArgs()
  file := r.LoadImage(strings.unsafe_string_to_cstring(filepath))
  defer r.UnloadImage(file)

  if !r.IsImageValid(file) {
    fmt.fprintfln(os.stderr, "Error: cannot open image at provided filepath: %v", filepath)
    os.exit(1)
  }

  r.SetConfigFlags({.VSYNC_HINT, .WINDOW_TOPMOST, .WINDOW_RESIZABLE})
  r.InitWindow(file.width, file.height, "sarp")
  defer r.CloseWindow()

  /* fix fragTexCoord for rectangles */
  tex := r.Texture2D {
    id      = rlgl.GetTextureIdDefault(),
    width   = 1,
    height  = 1,
    mipmaps = 1,
    format  = .UNCOMPRESSED_R8G8B8A8,
  }
  r.SetShapesTexture(tex, r.Rectangle{0, 0, 1, 1})

  tx := r.LoadTextureFromImage(file)
  txw := f32(tx.width)
  txh := f32(tx.height)

  cam := r.Camera2D {
    target = {txw / 2, txh / 2},
    zoom   = 1,
  }

  // [NOTE]: without this the internal window size doesn't get updated if the
  // window is resized automatically by the window manager on startup
  r.SetWindowSize(file.width, file.height)

  userZoom := f32(1)

  selection := SelectionState.None

  selectionRect := r.Rectangle{}

  selShaderData := #load("./selection.glsl")
  selShader := r.LoadShaderFromMemory(nil, cstring(&selShaderData[0]))

  timeUniform := r.GetShaderLocation(selShader, "time")
  sizeUniform := r.GetShaderLocation(selShader, "size")

  ui: for !r.WindowShouldClose() {
    if r.IsKeyPressed(.Q) {
      break
    }

    w := f32(r.GetRenderWidth())
    h := f32(r.GetRenderHeight())
    cam.offset = {w / 2, h / 2}

    wZoom := w / txw
    hZoom := h / txh
    cam.zoom = math.min(wZoom, hZoom) * userZoom

    userZoom = math.clamp(userZoom + r.GetMouseWheelMove() * .05, 0, 10)

    if r.IsMouseButtonDown(.MIDDLE) {
      delta := r.GetMouseDelta()
      if r.Vector2Length(delta) >= 1 {
        cam.target += delta * -1 / userZoom
      }
    }

    if r.IsMouseButtonDown(.LEFT) && selection != .Aborted {
      pos := r.GetScreenToWorld2D(r.GetMousePosition(), cam)

      if selection == .None {
        selectionRect.x = pos.x
        selectionRect.y = pos.y
        selection = .InProcess
      }

      selectionRect.width = pos.x - selectionRect.x
      selectionRect.height = pos.y - selectionRect.y
    }
    if r.IsMouseButtonReleased(.LEFT) {
      #partial switch selection {
      case .Aborted: selection = .None
      case .InProcess: break ui
      }
    }

    if r.IsMouseButtonPressed(.RIGHT) {
      selection = .Aborted
      selectionRect = {}
    }

    r.BeginDrawing(); {
      r.ClearBackground(r.BLACK)

      r.BeginMode2D(cam); {
        r.DrawTexturePro(tx, {0, 0, txw, txh}, {0, 0, txw, txh}, {0, 0}, 0, r.WHITE)
      }; r.EndMode2D()

      if selection == .InProcess {
        rect := fixRect(selectionRect)

        topLeft := r.GetWorldToScreen2D({rect.x, rect.y}, cam)
        bottomRight := r.GetWorldToScreen2D({rect.x + rect.width, rect.y + rect.height}, cam)
        screenRect := r.Rectangle{topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y}

        time := f32(r.GetTime())
        size := r.Vector2{screenRect.width, screenRect.height}
        r.SetShaderValue(selShader, timeUniform, &time, .FLOAT)
        r.SetShaderValue(selShader, sizeUniform, &size[0], .VEC2)

        r.BeginShaderMode(selShader); {
          r.DrawRectangleRec(screenRect, r.WHITE)
        }; r.EndShaderMode()
      }
    }; r.EndDrawing()
  }
  rect := clampRect(fixRect(selectionRect), {f32(file.width), f32(file.height)})

  sb: strings.Builder
  defer strings.builder_destroy(&sb)
  i := 0
  for i < len(outputFormat) {
    if outputFormat[i] == '%' {
      if (i + 1) >= len(outputFormat) {
        fmt.fprintln(os.stderr, "Error: invalid output format specifier.")
        os.exit(1)
      }
      i += 1
      switch outputFormat[i] {
      case 'w':
        strings.write_int(&sb, int(rect.width))
      case 'h':
        strings.write_int(&sb, int(rect.height))
      case 'x':
        strings.write_int(&sb, int(rect.x))
      case 'y':
        strings.write_int(&sb, int(rect.y))
      case:
        fmt.fprintln(os.stderr, "Error: invalid output format specifier.")
        os.exit(1)
      }
    } else {
      strings.write_byte(&sb, outputFormat[i])
    }
    i += 1
  }

  fmt.println(strings.to_string(sb))
}
