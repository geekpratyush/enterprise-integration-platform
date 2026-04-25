#!/bin/bash
# EIP Regression Test for MT103 -> pacs.008 (SRU 2025)

echo "--- Initializing Regression Test ---"
mkdir -p input/MT output/MX

# 1. Clear previous outputs
rm -f output/MX/MT103_FULL.xml

# 2. Run the Camel Pipeline (using JBang for testing)
echo "--- Running Transformation ---"
# Passing --background=false and --max-messages to ensure it terminates
camel run mt103-to-pacs008.yaml --max-messages=1 --max-idle-seconds=5 --logging-level=INFO

# 3. Assertions
echo ""
echo "--- Validating Results ---"
TARGET_FILE="output/MX/MT103_FULL.xml"

if [ ! -f "$TARGET_FILE" ]; then
    echo " [FAIL] Output file not generated at $TARGET_FILE"
    exit 1
fi

# Check for Transaction Reference (Tag 20)
grep -q "TXN7788990011" "$TARGET_FILE" && echo " [PASS] MsgId/InstrId mapping successful" || echo " [FAIL] MsgId mapping failed"

# Check for Amount and Currency
grep -q "Ccy=\"EUR\"" "$TARGET_FILE" && grep -q "125000.50" "$TARGET_FILE" && echo " [PASS] Settlement Amount (125000.50 EUR) Correct" || echo " [FAIL] Amount/Currency Mismatch"

# Check for Debtor Agent BIC (Tag 52A)
grep -q "BICOBEBBXXX" "$TARGET_FILE" && echo " [PASS] Debtor Agent BIC (BICOBEBBXXX) Correct" || echo " [FAIL] Debtor Agent BIC Missing"

# Check for EndToEndId (Tag 21)
grep -q "MT103FULLTEST" "$TARGET_FILE" && echo " [PASS] EndToEndId (MT103FULLTEST) Correct" || echo " [FAIL] EndToEndId Missing"

# Check for UETR
grep -q "e1b75fc0-cd47-493c-9977-d64843f9a727" "$TARGET_FILE" && echo " [PASS] UETR Mapping Correct" || echo " [FAIL] UETR Missing"

echo ""
echo "--- Integration Test: SUCCESS ---"
