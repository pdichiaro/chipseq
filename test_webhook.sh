#!/bin/bash
#
# Test script for webhook notifications
# This script helps you test your Slack or Teams webhook before running the full pipeline
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          ChIP-seq Pipeline Webhook Tester                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# Check if webhook URL is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: No webhook URL provided${NC}"
    echo
    echo "Usage:"
    echo "  $0 <webhook_url>"
    echo
    echo "Examples:"
    echo "  # Test Slack webhook"
    echo "  $0 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'"
    echo
    echo "  # Test Teams webhook"
    echo "  $0 'https://yourcompany.webhook.office.com/webhookb2/YOUR/WEBHOOK/URL'"
    echo
    exit 1
fi

WEBHOOK_URL="$1"

# Auto-detect service type
if [[ "$WEBHOOK_URL" == *"hooks.slack.com"* ]]; then
    SERVICE="Slack"
    TEMPLATE="slackreport"
elif [[ "$WEBHOOK_URL" == *"webhook.office.com"* ]]; then
    SERVICE="Microsoft Teams"
    TEMPLATE="adaptivecard"
else
    SERVICE="Unknown (will use Teams format)"
    TEMPLATE="adaptivecard"
fi

echo -e "${YELLOW}Detected service:${NC} $SERVICE"
echo -e "${YELLOW}Template:${NC} $TEMPLATE"
echo

# Test message payloads
if [ "$SERVICE" == "Slack" ]; then
    # Slack test message
    TEST_MESSAGE=$(cat <<'EOF'
{
    "attachments": [
        {
            "color": "good",
            "author_name": "chipseq v1.0.0 - test_run",
            "author_icon": "https://www.nextflow.io/docs/latest/_static/favicon.ico",
            "text": "✅ Test notification from ChIP-seq pipeline!",
            "fields": [
                {
                    "title": "Test Information",
                    "value": "This is a test webhook notification. If you see this message, your webhook is working correctly!",
                    "short": false
                }
            ],
            "footer": "Test completed at $(date)"
        }
    ]
}
EOF
)
else
    # Microsoft Teams test message (Adaptive Card)
    TEST_MESSAGE=$(cat <<'EOF'
{
    "type": "message",
    "attachments": [
        {
            "contentType": "application/vnd.microsoft.card.adaptive",
            "contentUrl": null,
            "content": {
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "msteams": {
                    "width": "Full"
                },
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Large",
                        "weight": "Bolder",
                        "color": "Good",
                        "text": "chipseq v1.0.0 - test_run",
                        "wrap": true
                    },
                    {
                        "type": "TextBlock",
                        "text": "✅ Test notification from ChIP-seq pipeline!",
                        "wrap": true
                    },
                    {
                        "type": "TextBlock",
                        "text": "This is a test webhook notification. If you see this message, your webhook is working correctly!",
                        "wrap": true
                    }
                ]
            }
        }
    ]
}
EOF
)
fi

echo -e "${BLUE}Sending test notification...${NC}"
echo

# Send the test message
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H 'Content-Type: application/json' \
    -d "$TEST_MESSAGE" \
    "$WEBHOOK_URL")

# Check response
if [ "$HTTP_RESPONSE" == "200" ]; then
    echo -e "${GREEN}✅ Success!${NC} Webhook test passed (HTTP $HTTP_RESPONSE)"
    echo
    echo "Your webhook is working correctly. You can now use it with the pipeline:"
    echo
    echo -e "${BLUE}nextflow run main.nf \\${NC}"
    echo -e "${BLUE}    --input samplesheet.csv \\${NC}"
    echo -e "${BLUE}    --genome GRCh38 \\${NC}"
    echo -e "${BLUE}    --outdir results \\${NC}"
    echo -e "${BLUE}    --hook_url '$WEBHOOK_URL'${NC}"
    echo
else
    echo -e "${RED}❌ Failed!${NC} Webhook test returned HTTP $HTTP_RESPONSE"
    echo
    echo "Possible issues:"
    echo "  • Invalid webhook URL"
    echo "  • Webhook has been revoked or disabled"
    echo "  • Network connectivity issues"
    echo "  • Firewall blocking the request"
    echo
    echo "Try:"
    echo "  1. Verify the webhook URL is correct"
    echo "  2. Check if the webhook is still active in your $SERVICE settings"
    echo "  3. Test from a different network"
    echo
    exit 1
fi
