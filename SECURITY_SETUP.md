# 🔒 Security Configuration Guide

## Overview
This document explains how environment variables are configured in this project to keep sensitive credentials secure.

## Important Files

### `.env` (Not in Git)
- Contains actual API keys, passwords, and other sensitive data
- **NEVER commit this file to version control**
- Already added to `.gitignore`

### `.env.example` (Tracked in Git)
- Template showing what environment variables are needed
- Contains placeholder values only
- Safe to commit to version control

## Setup Instructions

### For New Developers

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Fill in actual values:**
   - Open `.env` file
   - Replace all placeholder values with actual credentials
   - Get credentials from:
     - Team lead / project manager
     - Firebase Console
     - RapidAPI Dashboard
     - Supabase Dashboard
     - Gmail App Password settings

3. **Never commit `.env`:**
   - The `.gitignore` file prevents this automatically
   - Double-check before pushing code

## Environment Variables Reference

### 🍎 Edamam Nutrition API
- `EDAMAM_APP_ID` - Your Edamam application ID
- `EDAMAM_APP_KEY` - Your Edamam API key
- `EDAMAM_NUTRITION_API` - Edamam API endpoint

### 🗄️ Supabase
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anonymous/public key

### 💪 RapidAPI - Exercise Database
- `RAPIDAPI_KEY` - Your RapidAPI key for ExerciseDB
- `EXERCISE_DB_API_KEY` - Same as RAPIDAPI_KEY (legacy)

### 🔥 Firebase Configuration
- `FIREBASE_API_KEY_WEB` - Firebase web API key
- `FIREBASE_API_KEY_ANDROID` - Firebase Android API key
- `FIREBASE_API_KEY_IOS` - Firebase iOS API key
- `FIREBASE_APP_ID_WEB` - Firebase web app ID
- `FIREBASE_APP_ID_ANDROID` - Firebase Android app ID
- `FIREBASE_APP_ID_IOS` - Firebase iOS app ID
- `FIREBASE_MESSAGING_SENDER_ID` - FCM sender ID
- `FIREBASE_PROJECT_ID` - Firebase project ID
- `FIREBASE_AUTH_DOMAIN` - Firebase auth domain
- `FIREBASE_STORAGE_BUCKET` - Firebase storage bucket
- `FIREBASE_MEASUREMENT_ID_WEB` - Google Analytics measurement ID (web)
- `FIREBASE_MEASUREMENT_ID_WINDOWS` - Google Analytics measurement ID (windows)
- `FIREBASE_IOS_BUNDLE_ID` - iOS bundle identifier

### 📧 Gmail SMTP (Email Notifications)
- `SMTP_SENDER_EMAIL` - Gmail address for sending emails
- `SMTP_SENDER_NAME` - Display name for sent emails
- `SMTP_APP_PASSWORD` - Gmail app password (NOT your regular password)
- `SMTP_HOST` - SMTP server (default: smtp.gmail.com)
- `SMTP_PORT` - SMTP port (default: 587)

## How to Get Credentials

### Gmail App Password
1. Go to your Google Account settings
2. Navigate to Security → 2-Step Verification
3. Scroll to "App passwords"
4. Generate a new app password for "Mail"
5. Use this 16-character password in `SMTP_APP_PASSWORD`

### Firebase Keys
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Project Settings → General
4. Scroll to "Your apps" section
5. Find platform-specific configuration values

### RapidAPI Key
1. Go to [RapidAPI](https://rapidapi.com)
2. Sign in to your account
3. Navigate to ExerciseDB API
4. Copy your API key from the dashboard

### Supabase Keys
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to Settings → API
4. Copy the URL and anon/public key

## Security Best Practices

### ✅ DO
- Keep `.env` file locally only
- Use strong, unique credentials
- Rotate API keys regularly
- Use different credentials for development/production
- Share credentials securely (e.g., password manager, encrypted channels)

### ❌ DON'T
- Commit `.env` to version control
- Share credentials in plain text (Slack, email, etc.)
- Use production credentials in development
- Hardcode credentials in source files
- Push code without checking `.gitignore`

## Troubleshooting

### "Missing SMTP_APP_PASSWORD" Error
- Ensure `.env` file exists in project root
- Check that `SMTP_APP_PASSWORD` is set
- Verify the app password is correct (16 characters, no spaces)

### Firebase Initialization Fails
- Verify all `FIREBASE_*` variables are set in `.env`
- Check that `.env` is being loaded before Firebase.initializeApp()
- Ensure Firebase project credentials match your Firebase Console

### API Calls Failing
- Confirm API keys are valid and not expired
- Check API usage limits haven't been exceeded
- Verify the API key has necessary permissions

## Files Modified

The following files have been updated to use environment variables:

1. **`lib/firebase_options.dart`** - Firebase configuration
2. **`lib/core/services/emails/email_service.dart`** - Email SMTP settings
3. **`lib/main.dart`** - Early .env loading
4. **`.gitignore`** - Added .env exclusion
5. **`.env`** - Contains actual credentials (not tracked)
6. **`.env.example`** - Template file (tracked)

## Support

If you need access to credentials or have security concerns:
1. Contact the project maintainer
2. Never share credentials publicly
3. Report any exposed credentials immediately
