# MicMonitor

## Problem

There is no great native way to handle knowing when microphone is being used and what process is using the system microphone in electron. I spent a lot of time researching how to do this till I found a rare gem. Oversight - OverSight monitors a mac's mic and webcam, alerting the user when the internal mic is activated, or whenever a process accesses the webcam.

The Oversight application does a lot of things besides just detecting microphone activity.

So I made a binary executable utility to detect only microphone activity using the original Oversight approach.

This is a lightweight utility to help detect microphone activity and what process is activating it.

This is an overly simplified version of the [oversight](https://github.com/objective-see/OverSight) macos utility tool that helps detect when microphone or camera are active and what processes are using them

### Command Line Build

```bash
cd MicMonitor
xcodebuild -project MicMonitor.xcodeproj -target MicMonitor -configuration Release
```

The built executable will be in `build/Release/MicMonitor`.

## Usage

### Basic Usage

```bash
cd /build/Release/MicMonitor
./MicMonitor
```

### Command Line Options

```bash
./MicMonitor [options]

Options:
  -h, --help     Show help message
  -v, --version  Show version information
  -j, --json     Output events in JSON format (default)
```

CREDITS: Oversight
