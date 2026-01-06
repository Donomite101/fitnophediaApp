# ✅ Pre-Commit Security Checklist

Use this checklist before pushing code to Git repository.

## 🔐 Before First Push (CRITICAL)

- [ ] **Rotate Firebase Admin Service Account Key**
  - Go to Firebase Console → Project Settings → Service Accounts
  - Delete the old key
  - Generate new key and store it securely (NOT in repo)

- [ ] **Rotate Gmail App Password**
  - Go to Google Account → Security → 2-Step Verification → App passwords
  - Revoke old password
  - Generate new password
  - Update `.env` file

- [ ] **Verify .gitignore is working**
  ```bash
  git status
  # .env should NOT appear in the list
  ```

- [ ] **Remove .env from Git tracking if previously added**
  ```bash
  git rm --cached .env
  git rm --cached assets/*firebase-adminsdk*.json
  ```

## 📋 Before Every Commit

- [ ] **Check for hardcoded secrets**
  ```bash
  # Search for potential hardcoded API keys
  grep -r "apiKey.*:" lib/ --exclude-dir={build,node_modules}
  grep -r "password.*:" lib/ --exclude-dir={build,node_modules}
  ```

- [ ] **Verify .env is not staged**
  ```bash
  git diff --cached --name-only | grep ".env"
  # Should return nothing
  ```

- [ ] **Check for Firebase service account files**
  ```bash
  git diff --cached --name-only | grep "firebase-adminsdk"
  # Should return nothing
  ```

## 🎯 Before Pushing to Remote

- [ ] **.env file exists locally** (for your own testing)
- [ ] **.env is in .gitignore**
- [ ] **.env.example is committed** (template for team)
- [ ] **No credentials in commit messages**
- [ ] **SECURITY_SETUP.md is committed** (documentation)

## 🚀 Ready to Push!

If all checkboxes are checked, you're safe to push:

```bash
git add .
git commit -m "Your commit message"
git push origin main
```

## 🆘 Emergency: Credentials Exposed

If you accidentally pushed credentials:

1. **Rotate ALL credentials immediately**
2. **Use BFG Repo-Cleaner to remove from history:**
   ```bash
   # Download BFG from: https://rtyley.github.io/bfg-repo-cleaner/
   java -jar bfg.jar --delete-files .env
   java -jar bfg.jar --delete-files '*firebase-adminsdk*.json'
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   ```
3. **Force push (coordinate with team first!):**
   ```bash
   git push --force
   ```
4. **Notify your team**

## 📚 Resources

- `SECURITY_SETUP.md` - Complete setup guide
- `SECURITY_AUDIT_REPORT.md` - What was fixed
- `.env.example` - Template for environment variables
