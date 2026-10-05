# Pollen Pet

A macOS app that puts a talking robot on your desktop.
Choose [Microduck](https://pollen-robotics.com/microduck/)
or [Reachy Mini](https://pollen-robotics.com/reachy-mini/)
from [Pollen Robotics](https://pollen-robotics.com),
and chat through short conversations
with synchronized speech, text, and motion.

https://github.com/user-attachments/assets/51a6a64f-f91c-4059-a8f2-735e29fcc116

> [!NOTE]
> Pollen Pet is an independent, noncommercial project.
> The Microduck and Reachy Mini models are licensed for noncommercial use only.

## Features

- **Two robots** —
  Microduck and Reachy Mini, rendered with RealityKit
  from models converted from Pollen Robotics' own sources
- **Synthesized voices** —
  Each robot chirps in its own register,
  with accent tones for questions, exclamations, and sentence ends
- **One clock for everything** —
  Text, voice, mouth movement, gestures, and reactions
  play from a single timeline that follows the audio
- **Branching conversations** —
  Five scenes per robot, each with two replies
- **A desktop companion** —
  A transparent window that you move by dragging the robot;
  clicks outside the robot and dialogue pass through to the windows behind it
- **Attention** —
  The robot turns its body and head toward the pointer
- **Custom colors** —
  Repaint Microduck's head, body, beak, and feet
- **Accessibility** —
  VoiceOver labels, full keyboard control,
  instant text, mute, and support for Reduce Motion

## Getting Started

### Prerequisites

- macOS 15 or later
- Xcode 16 or later

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/mattt/pollen-pets.git
cd pollen-pets
```

2. **Open in Xcode**

```bash
xed PollenPet.xcodeproj
```

3. **Build and run**

Press <kbd>⌘</kbd><kbd>R</kbd> to build and run the application.

## Usage

When the app opens, Microduck appears with the first line of a conversation.
When the robot asks a question, two replies appear above the dialogue.
Choose one, and the robot responds in two more lines.
At the end of a scene, you can start again or move on to the next scene.

| Action                       | Control                                                         |
| ---------------------------- | --------------------------------------------------------------- |
| Reveal or continue a line    | Click the dialogue, or press <kbd>Space</kbd>                   |
| Choose a reply               | Click it, use <kbd>↑</kbd> <kbd>↓</kbd> and <kbd>Return</kbd>, or press <kbd>1</kbd> or <kbd>2</kbd> |
| Replay the scene             | <kbd>⌘</kbd><kbd>R</kbd>                                        |
| Choose a character           | Click the name badge, or press <kbd>⌘</kbd><kbd>K</kbd>         |
| Customize Microduck's colors | Click **Customize…** in the dialogue header                     |
| Open Settings                | <kbd>⌘</kbd><kbd>,</kbd>                                        |
| Move the window              | Drag the robot                                                  |

Settings has options to choose a scene, show text instantly, and mute sound.
The app also follows the system Reduce Motion setting.

For screenshots and debugging,
the app accepts these launch arguments:

| Argument                            | Effect                                 |
| ----------------------------------- | -------------------------------------- |
| `--pet=microduck`, `--pet=reachy-mini` | Start with that robot               |
| `--scene=hello` (or `discovery`, `tired`, `teasing`, `package`) | Start with that scene |
| `--instant`                         | Show each line at once, without audio  |
| `--reduce-motion`                   | Turn off decorative motion             |

## How It Works

Each line of dialogue is a list of spans,
and each span can add a text effect, a slower delivery,
a head gesture, or a reaction.
`PerformanceCompiler` turns a line into a `Performance`:
one timeline with the moment each character appears,
the voice's chirps and accents,
and the start of each gesture and reaction.

`VoiceRenderer` synthesizes the whole performance into one audio buffer.
`PlaybackController` then reads the audio engine's sample time,
so that text, mouth, and head motion stay in sync with what you hear,
even when you pause or mute.
On each RealityKit frame, the stage samples that clock to pose the robot.
A SwiftUI `TextRenderer` uses the same clock to reveal and animate the text.

The window is transparent and borderless.
Each robot part has a convex collision shape that follows its joint,
so the app can test the pointer against the robot's current pose
and pass all other clicks through to the desktop.

| Directory      | Contents                                                          |
| -------------- | ----------------------------------------------------------------- |
| `App/`         | SwiftUI interface, RealityKit stage, and window behavior          |
| `App/Core/`    | Dialogue, performance compiler, voice, playback, and animators    |
| `Assets/`      | Images for this README                                            |
| `Resources/`   | Robot models, character portraits, and the heading font           |
| `Scripts/`     | Scripts that convert the upstream robot models to USDZ            |
| `Tests/`       | Swift Testing suites                                              |
| `ThirdParty/`  | Model sources, conversion records, and license notices            |

## Development

To run the tests from the command line:

```bash
xcodebuild test -project PollenPet.xcodeproj -scheme PollenPet \
  -destination 'platform=macOS'
```

The tests load the bundled models with RealityKit,
so run them in a session with access to the GPU.

The Xcode project uses synchronized folders,
so new files in `App/` and `Tests/` join their targets automatically.

To rebuild a robot model from its pinned upstream source,
see [ThirdParty/README.md](ThirdParty/README.md).

## License

The code in this project is available under the Apache License, Version 2.0.
See the [LICENSE](LICENSE) file for more info.

The bundled models and font keep their own licenses:

- The Microduck model is by Pollen Robotics,
  under Creative Commons BY-SA-NC,
  which does not permit commercial use.
- The Reachy Mini model is by Clément Plays for Pollen Robotics,
  under the Apache License, Version 2.0.
- The Anton font is by Vernon Adams,
  under the SIL Open Font License, Version 1.1.

See [ThirdParty/README.md](ThirdParty/README.md) for sources and details.

## Legal

Microduck and Reachy Mini are products of Pollen Robotics.
This project is not affiliated with or endorsed by Pollen Robotics.
