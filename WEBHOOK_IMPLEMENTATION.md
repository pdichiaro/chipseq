# Webhook Notification Implementation

## ✅ Implementation Complete

The `hook_url` parameter has been successfully added to the chipseq pipeline to enable automatic notifications to Slack and Microsoft Teams when workflows complete.

## 📁 Files Modified/Created

### 1. **nextflow_schema.json** (Modified)
Added new parameter definition in the `generic_options` section:

```json
"hook_url": {
    "type": "string",
    "description": "Incoming hook URL for messaging service",
    "fa_icon": "fas fa-people-group",
    "help_text": "Incoming hook URL for messaging service. Currently, MS Teams and Slack are supported.",
    "hidden": true
}
```

### 2. **assets/slackreport.json** (Created)
Template for Slack notifications with:
- Color-coded status (green for success, red for failure)
- Pipeline name and version
- Execution details (command line, duration)
- Error messages (only on failure)

### 3. **assets/adaptivecard.json** (Created)
Template for Microsoft Teams notifications using Adaptive Cards format with:
- Rich formatted cards
- Expandable configuration section
- Pipeline status and metadata

### 4. **workflows/chipseq.nf** (Modified)

#### Added webhook integration in `workflow.onComplete` block:
```groovy
workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    
    // Send webhook notification if hook_url is provided
    if (params.hook_url) {
        sendWebhookNotification(summary_params, params.hook_url)
    }
}
```

#### Added `sendWebhookNotification()` function:
- Collects workflow metadata (status, duration, errors, etc.)
- Auto-detects service type (Slack vs Teams) based on URL
- Renders appropriate JSON template
- POSTs notification to webhook URL
- Logs warnings if POST fails

## 🚀 Usage

### Slack Example
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --genome GRCh38 \
    --outdir results \
    --hook_url 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
```

### Microsoft Teams Example
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --genome GRCh38 \
    --outdir results \
    --hook_url 'https://yourcompany.webhook.office.com/webhookb2/YOUR/WEBHOOK/URL'
```

### Configuration File
```groovy
// custom.config
params {
    hook_url = 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
}
```

Then run:
```bash
nextflow run main.nf -c custom.config --input samplesheet.csv
```

## 🔍 How It Works

### Execution Flow

```
Pipeline Execution
       ↓
workflow.onComplete {} triggered
       ↓
Check if params.hook_url is set
       ↓
sendWebhookNotification() function called
       ↓
Collect workflow metadata
       ↓
Detect service (Slack vs Teams)
       ↓
Load and render JSON template
       ↓
POST to webhook URL
       ↓
Log result
```

### Automatic Service Detection

- **URL contains "hooks.slack.com"** → Uses `slackreport.json` template
- **Any other URL** → Uses `adaptivecard.json` template (Microsoft Teams format)

### Metadata Collected

**Always included:**
- Pipeline name and version
- Run name
- Success/failure status
- Start and completion time
- Duration
- Exit status
- Command line (with hook_url redacted for security)

**On failure:**
- Full error message
- Error report
- Pipeline configuration summary

## 🛡️ Security Features

1. **URL Redaction**: The `hook_url` is automatically removed from the command line shown in notifications
2. **Error Handling**: Failed webhook POSTs are logged as warnings (don't fail the pipeline)
3. **Hidden Parameter**: The parameter is marked as `"hidden": true` in the schema

## 🧪 Testing

To test your webhook without running the full pipeline:

### Manual Test with curl

**Slack:**
```bash
curl -X POST -H 'Content-Type: application/json' \
     -d '{"text":"Test notification from chipseq pipeline"}' \
     https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**Microsoft Teams:**
```bash
curl -X POST -H 'Content-Type: application/json' \
     -d '{
       "type":"message",
       "attachments":[{
         "contentType":"application/vnd.microsoft.card.adaptive",
         "content":{
           "type":"AdaptiveCard",
           "body":[{"type":"TextBlock","text":"Test from chipseq"}],
           "$schema":"http://adaptivecards.io/schemas/adaptive-card.json",
           "version":"1.2"
         }
       }]
     }' \
     https://yourcompany.webhook.office.com/webhookb2/YOUR/WEBHOOK/URL
```

## 📚 Related Parameters

The webhook notification complements existing notification features:

- `--email`: Email address for completion summary (always sent)
- `--email_on_fail`: Email address for failures only
- `--plaintext_email`: Send plain-text emails instead of HTML

You can use multiple notification methods simultaneously:

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --email you@example.com \
    --email_on_fail alerts@example.com \
    --hook_url 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
```

## 🐛 Troubleshooting

### Webhook Not Received

1. **Verify webhook URL is valid** - Test with curl
2. **Check network connectivity** - Ensure compute environment can reach the webhook endpoint
3. **Review Nextflow logs** - Look for warning messages from the POST request
4. **Check webhook service status** - Verify Slack/Teams webhook hasn't been revoked

### "Reached automation hook" Message

If the pipeline appears to hang after completion with this message:
- The webhook POST may be timing out
- Try removing `--hook_url` temporarily to verify pipeline completes normally
- Check firewall/proxy settings

### Response Code != 200

If you see warnings in the logs:
- The webhook service returned an error
- Check the error stream output in the logs
- Verify the webhook URL hasn't expired or been disabled

## 🎯 Best Practices

1. **Store URLs in config files** - Don't expose webhook URLs in command history
2. **Use environment variables** - `export NXF_HOOK_URL='...'` for sensitive URLs
3. **Separate channels for environments** - Different webhooks for dev/staging/production
4. **Combine with email** - Use both webhooks and email for redundancy
5. **Test before production** - Verify webhooks work with test pipelines first

## 🔗 Resources

- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [Microsoft Teams Webhooks](https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook)
- [Adaptive Cards](https://adaptivecards.io/)
- [nf-core notification documentation](https://nf-co.re/docs/usage/notifications)

## ✨ Summary

The webhook notification feature is now fully integrated into your chipseq pipeline! It provides:

- ✅ Real-time completion notifications
- ✅ Support for Slack and Microsoft Teams
- ✅ Automatic service detection
- ✅ Comprehensive workflow metadata
- ✅ Security (URL redaction)
- ✅ Error handling (non-blocking failures)
- ✅ Compatible with existing email notifications

Use `--hook_url` to keep your team instantly informed about pipeline executions! 🚀
