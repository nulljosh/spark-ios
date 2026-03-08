# Spark iOS - Claude Guide

## Overview
iOS companion for [Spark](https://github.com/nulljosh/spark). Idea-sharing with voting.

## Stack
- SwiftUI, iOS 17+, @Observable
- Supabase backend (shared with web app)

## Design
- Apple Liquid Glass: .ultraThinMaterial, blur, rounded corners, system font
- Accent: #0071e3 blue
- No emojis

## Roadmap
- [ ] Supabase auth (shared with web)
- [ ] Feed: load posts from Supabase
- [ ] Voting: upvote/downvote with per-user tracking
- [ ] Create: post new ideas
- [ ] Profile: user stats, own posts
- [ ] Push notifications for votes on your posts

## Build
```bash
open SparkApp.swift  # Opens in Xcode
# Or: xcodebuild -scheme Spark -destination 'platform=iOS Simulator'
```

## Quick Commands
- `./scripts/simplify.sh`
- `./scripts/monetize.sh . --write`
- `./scripts/audit.sh .`
- `./scripts/ship.sh .`
