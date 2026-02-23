# 🎉 Webhook Notification Setup - Complete Summary

## ✅ Implementation Status: COMPLETE

The `hook_url` parameter has been successfully implemented in your chipseq pipeline, providing real-time notifications to Slack and Microsoft Teams.

---

## 📦 What Was Added

### 1️⃣ Core Implementation

| File | Status | Purpose |
|------|--------|---------|
| `nextflow_schema.json` | ✅ Modified | Added `hook_url` parameter definition |
| `workflows/chipseq.nf` | ✅ Modified | Added webhook notification logic |
| `assets/slackreport.json` | ✅ Created | Slack notification template |
| `assets/adaptivecard.json` | ✅ Created | Microsoft Teams notification template |

### 2️⃣ Documentation & Tools

| File | Purpose |
|------|---------|
| `WEBHOOK_IMPLEMENTATION.md` | Implementation guide and usage instructions |
| `conf/notifications.config` | Example configuration file with all options |
| `test_webhook.sh` | Testing script for webhook validation |

---

## 🚀 Quick Start

### Step 1: Set Up Your Webhook

#### For Slack:
1. Go to https://api.slack.com/apps
2. Create/select app → Enable "Incoming Webhooks"
3. Add webhook to workspace → Select channel
4. Copy webhook URL (format: `https://hooks.slack.com/services/...`)

#### For Microsoft Teams:
1. Open Teams channel → "..." → "Connectors"
2. Search "Incoming Webhook" → "Configure"
3. Set name and image → Copy webhook URL

### Step 2: Test Your Webhook

```bash
./test_webhook.sh 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
```

You should see: ✅ Success! Webhook test passed (HTTP 200)

### Step 3: Run Pipeline with Notifications

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --genome GRCh38 \
    --outdir results \
    --hook_url 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
```

---

## 🎯 Usage Examples

### Example 1: Slack Notification Only
```bash
nextflow run main.nf \
    --input samples.csv \
    --genome GRCh38 \
    --hook_url 'https://hooks.slack.com/services/T00/B00/XXX'
```

### Example 2: Combined Email + Slack
```bash
nextflow run main.nf \
    --input samples.csv \
    --genome GRCh38 \
    --email you@example.com \
    --email_on_fail alerts@example.com \
    --hook_url 'https://hooks.slack.com/services/T00/B00/XXX'
```

### Example 3: Using Configuration File
```bash
# Edit conf/notifications.config with your webhook URL
nextflow run main.nf \
    -c conf/notifications.config \
    --input samples.csv \
    --genome GRCh38
```

### Example 4: Environment Variable (Secure)
```bash
# Set environment variable
export PIPELINE_WEBHOOK='https://hooks.slack.com/services/T00/B00/XXX'

# Use in config file
echo "params.hook_url = System.getenv('PIPELINE_WEBHOOK')" > custom.config

# Run pipeline
nextflow run main.nf -c custom.config --input samples.csv
```

---

## 📊 What Gets Notified

### On Success ✅
- Pipeline name and version
- Run name
- Completion time and duration
- Exit status
- Command line used

### On Failure ❌
All of the above, plus:
- Full error message
- Error report details
- Pipeline configuration summary

---

## 🔍 How It Works

```
┌─────────────────────────────────────────────────────────┐
│  Pipeline Execution                                     │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  workflow.onComplete {} triggered                       │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  Check: Is params.hook_url set?                         │
└────────────┬────────────┬───────────────────────────────┘
             │ No         │ Yes
             ▼            ▼
         [Skip]  ┌────────────────────────────────┐
                 │ sendWebhookNotification()      │
                 └────────────┬───────────────────┘
                              │
                              ▼
                 ┌────────────────────────────────┐
                 │ Detect Service Type:           │
                 │ • Slack? → slackreport.json    │
                 │ • Other  → adaptivecard.json   │
                 └────────────┬───────────────────┘
                              │
                              ▼
                 ┌────────────────────────────────┐
                 │ Render JSON Template           │
                 └────────────┬───────────────────┘
                              │
                              ▼
                 ┌────────────────────────────────┐
                 │ POST to Webhook URL            │
                 └────────────┬───────────────────┘
                              │
              ┌───────────────┴────────────────┐
              ▼                                ▼
    ┌──────────────────┐          ┌──────────────────┐
    │ HTTP 200 ✅      │          │ HTTP != 200 ⚠️  │
    │ Success          │          │ Log Warning      │
    └──────────────────┘          └──────────────────┘
```

---

## 🛡️ Security Features

| Feature | Description |
|---------|-------------|
| **URL Redaction** | `hook_url` is automatically removed from command line in notifications |
| **Hidden Parameter** | Not shown in `--help` output by default |
| **Non-Blocking** | Failed webhook POST logs warning but doesn't fail pipeline |
| **Environment Variables** | Support for storing URLs as env vars |

---

## 📚 Files Reference

### Implementation Files
```
chipseq/
├── nextflow_schema.json              # Parameter definition
├── workflows/chipseq.nf              # Webhook logic
└── assets/
    ├── slackreport.json              # Slack template
    └── adaptivecard.json             # Teams template
```

### Documentation Files
```
chipseq/
├── WEBHOOK_IMPLEMENTATION.md         # Full implementation guide
├── WEBHOOK_SETUP_SUMMARY.md         # This file
└── conf/
    └── notifications.config          # Example config with all options
```

### Utility Scripts
```
chipseq/
└── test_webhook.sh                   # Webhook testing tool
```

---

## 🧪 Testing Checklist

- [ ] Run `./test_webhook.sh 'YOUR_WEBHOOK_URL'`
- [ ] Verify you receive test notification
- [ ] Run a small test pipeline with `--hook_url`
- [ ] Check notification appears in your channel
- [ ] Verify success notification format
- [ ] Test failure notification (cancel a run)
- [ ] Confirm email notifications still work (if using)

---

## 🐛 Troubleshooting

### Problem: Webhook not received

**Solutions:**
1. Test with `./test_webhook.sh` first
2. Verify webhook URL is still valid
3. Check network connectivity from compute environment
4. Look for warnings in `.nextflow.log`

### Problem: Pipeline hangs with "Reached automation hook"

**Solutions:**
1. This is a known issue with webhook timeouts
2. Remove `--hook_url` temporarily to verify pipeline completes
3. Check firewall/proxy settings
4. Verify webhook service is responding

### Problem: HTTP 400/401/403 errors

**Solutions:**
1. Webhook URL may be expired or revoked
2. Regenerate webhook in Slack/Teams
3. Check URL is copied correctly (no extra spaces)

---

## 💡 Best Practices

### ✅ DO
- Store webhook URLs in config files or environment variables
- Use separate webhooks for production vs development
- Test webhooks before production runs
- Combine with email for redundancy
- Keep webhook URLs private and secure
- Use descriptive channel names

### ❌ DON'T
- Commit webhook URLs to version control
- Share webhook URLs publicly
- Use the same webhook across all environments
- Ignore webhook test failures
- Forget to rotate URLs periodically

---

## 🔗 Related Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--email` | Email for all completions | `you@example.com` |
| `--email_on_fail` | Email only on failures | `alerts@example.com` |
| `--plaintext_email` | Use plain text emails | `true` |
| `--hook_url` | Webhook URL | `https://hooks.slack.com/...` |

---

## 🌟 Key Features

- ✅ **Auto-Detection**: Automatically detects Slack vs Teams by URL
- ✅ **Rich Formatting**: Beautiful formatted messages with status colors
- ✅ **Error Details**: Full error messages and reports on failures
- ✅ **Security**: URL redacted from notifications
- ✅ **Non-Blocking**: Webhook failures don't stop pipeline
- ✅ **Flexible**: Works with command line, config files, or env vars
- ✅ **Tested**: Includes test script for validation

---

## 📖 Additional Resources

- [Slack Webhook Documentation](https://api.slack.com/messaging/webhooks)
- [Teams Webhook Documentation](https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook)
- [Adaptive Cards](https://adaptivecards.io/)
- [nf-core Notifications](https://nf-co.re/docs/usage/notifications)

---

## ✨ Summary

Your chipseq pipeline now supports **real-time webhook notifications** to Slack and Microsoft Teams! 

🎯 **Next Steps:**
1. Set up a webhook in Slack or Teams
2. Test with `./test_webhook.sh`
3. Run a test pipeline with `--hook_url`
4. Configure `conf/notifications.config` for permanent setup

**Happy Pipeline Running!** 🚀

---

*Implementation Date: 2026-02-23*  
*Based on nf-core/chipseq webhook implementation*
