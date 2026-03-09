# Spark iOS - Claude Guide

## Overview
iOS companion for [Spark](https://github.com/nulljosh/spark). Idea-sharing with voting.

## Stack
- SwiftUI, iOS 17+, @Observable
- Vercel serverless + Supabase DB

## Design
- Apple Liquid Glass: .ultraThinMaterial, blur, rounded corners, system font
- Accent: #0071e3 blue
- No emojis

## Features
- Auth: login/register with JWT/Keychain
- Feed: load posts, pull-to-refresh, search, category filter
- Voting: optimistic upvote/downvote with debounce, error revert
- Create: post new ideas with category picker
- Profile: user stats, own posts, swipe-to-delete
- Delete posts (owner only, error surfaced via banner)
- Error banner system (auth errors, API failures)
- Test infrastructure: 12 unit tests via MockSparkAPI

## Roadmap
- [x] Auth (login/register, JWT/Keychain)
- [x] Feed: load posts from API
- [x] Voting: upvote/downvote with per-user tracking
- [x] Create: post new ideas
- [x] Profile: user stats, own posts
- [ ] Push notifications for votes on your posts

## Build
```bash
xcodegen generate && open Spark.xcodeproj
# Or: xcodebuild -scheme Spark -destination 'platform=iOS Simulator'
```

## Quick Commands
- `./scripts/simplify.sh`
- `./scripts/monetize.sh . --write`
- `./scripts/audit.sh .`
- `./scripts/ship.sh .`
