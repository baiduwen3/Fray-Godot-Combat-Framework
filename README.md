# ![Stray Banner](docs/stray_banner.png)

![Stray status](https://img.shields.io/badge/status-alpha-red) ![Godot version](https://img.shields.io/badge/godot-v3.4-blue)  ![License](https://img.shields.io/badge/license-MIT-informational)

Stray is a work in progress addon for the [Godot Game Engine](https://godotengine.org). It features tools for implementing action / fighting game style combat such as hit detection, input buffering, and fighter state management.

## ⚠️ Important

**This addon is in alpha! Extensive testing is still required, breaking changes may still be made, and parts of the features below may not yet be fully implemented.**

## ✨ Core Features

### Hit Box Management

Stray provides tools for setting up and managing a fighter's hitbox / attackbox based on their current state.

### Combat State Management

Stray features a hiearchacel state machine that allows you to keep track of a fighter's combat state and automatically advance to new states based on the player's inputs. In other words this system lets you switch from one attack to another following a predefined "action graph".

Through this system SCF supports the implementation of [chaining](https://glossary.infil.net/?t=Chain).

### Input Buffering

Inputs fed to stray's combat state management system are buffered allowing a player to queue their next action before the current action has finished. [Buffering](https://en.wiktionary.org/wiki/Appendix:Glossary_of_fighting_games#Buffering) is an important feature in action games as without it players would need frame perfect inputs to perform their actions.

### Complex Input Detection

Stray provides tools for detecting the 'complex' inputs featured in many fighting games such as [directional inputs](https://mugen.fandom.com/wiki/Command_input#Directional_inputs), [motion inputs](https://mugen.fandom.com/wiki/Command_input#Motion_input), [charged inputs](https://clips.twitch.tv/FuriousObservantOrcaGrammarKing-c1wo4zhroMVZ9I7y), and [sequence inputs](https://mugen.fandom.com/wiki/Command_input#Sequence_inputs).

## ⚙ Installation

1. Clone or download a copy of this repository.
2. Copy the contents of `addons/` into your `res://addons/` directory.
3. Enable `Stray Combat Framework` in your project plugins.

If you would like to know more about installing plugins see the [Official Godot Docs](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html).

## 📚 Documentation

- Getting Started (Coming Eventually)
- Stray API (Coming Eventually)

## 📃 Credits

### 🎨 Assets

- Controller Button Images : <https://thoseawesomeguys.com/prompts/>
- Player Example Sprite : <https://www.spriters-resource.com/playstation_2/mbaa/sheet/28116/>
