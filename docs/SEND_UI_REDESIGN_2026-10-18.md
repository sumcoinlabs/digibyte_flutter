# DigiByte Wallet — Send UI Redesign

Date: October 18, 2026
Development branch: feat/send-ui-refresh-20261018
Starting release version: 0.1.4, Build 14
Status: Work in progress — NOT APPROVED FOR MASTER

## 1. Executive Summary

This branch redesigns the DigiByte Wallet Send screen while
preserving its existing visual identity and transaction infrastructure.

Primary goals:

- Make sending easier on an iPhone without unnecessary scrolling.
- Preserve DigiByte's blue background, navy panels, and theme.
- Keep address entry, Paste, and QR scanning close together.
- Replace the previous "Empty wallet" terminology with "All".
- Make DGB/fiat amount entry understandable and predictable.
- Respect the fiat currency selected in wallet settings.
- Display useful exchange-rate and amount-conversion information.
- Replace the system numeric keyboard with an embedded keypad.
- Preserve advanced transaction capabilities.
- Prevent repeated QR scan events from navigating multiple routes.
- Keep the existing transaction builder, signing, and fee logic.

This is a feature branch, not a production release or completed
security review.

## 2. Problems in the Original Send Screen

The previous interface had several usability problems:

- The scan action could require scrolling to reach.
- Recipient entry and QR scanning were visually disconnected.
- Fiat/coin switching was not immediately obvious.
- "Empty wallet" sounded destructive and was poorly positioned.
- Secondary functions occupied too much vertical space.
- The Send action was crowded by lower-screen content.
- The amount keyboard obscured important parts of the interface.
- The screen had inconsistent spacing around its form controls.
- The conversion display could be difficult to interpret.
- An intermittent QR scan navigation problem had been reported.

The redesign addresses those issues incrementally rather than
replacing the wallet's payment-processing architecture.

## 3. Changed Source Files

### lib/widgets/wallet/send_tab.dart

Main Send form, layout, keypad, conversion controls, All action,
validation, advanced-options presentation, and QR result handling.

### lib/widgets/wallet/wallet_balance_header.dart

Adds support for a compact balance header. The Send screen can
collapse its balance header while amount entry is active, creating
more space for the embedded keypad and lower advertising area.

### lib/screens/qrcode_scanner.dart

Updates the shared QR scanner's event handling and lifecycle.

### assets/translations/en.json

Adds English translation entries for the redesigned interface,
including All, Advanced Options, Paste, and currency selection.

Existing translations and non-English localization coverage
require review before release.

### docs/SEND_UI_REDESIGN_2026-10-18.md

This development history, functional specification, known-issues
list, regression plan, and release checklist.

## 4. Normal Send Workflow

The normal Send view retains:

1. Wallet/header information.
2. Recipient address entry.
3. Paste and QR scanning controls beside the address field.
4. Optional recipient label.
5. Amount entry.
6. DGB or selected fiat currency.
7. All button.
8. Live conversion information.
9. Expandable Advanced Options.
10. Send action and transaction confirmation.

The duplicate bottom QR-scanning button was eliminated.

The application theme and existing visual identity remain intact.

## 5. Address Entry

Existing address validation and address-book suggestions remain.

Paste uses the clipboard and trims surrounding whitespace.

The QR scanner is accessed directly beside the address input.

The address field continues to support recipient labels.

QR entry and manual entry feed into the existing Send form.

Invalid addresses must be rejected before transaction confirmation.

Address-book suggestions and already-saved recipient labels must
continue to work.

## 6. Optional Address Label

The Send form retains an optional recipient label, with a maximum
of 32 characters.

Existing address-label storage is not redesigned in this branch.

Current wallet labels are local application metadata. A seed
phrase alone does not encode or recover these labels.

Known limitation:

Deleting the application and restoring from the seed can lose
recipient labels and address-book metadata.

A separate label backup/synchronization feature is needed.

Possible future approach:

- Define a versioned address-book export schema.
- Store recipient addresses, labels, and relevant wallet identifiers.
- Keep seed phrases and private keys OUT of label exports.
- Offer encrypted export/import with clear recovery instructions.
- Evaluate optional encrypted cloud synchronization.
- Handle restore conflicts and duplicate address records.
- Test reinstall and recovery with multiple wallets.

No automatic cloud synchronization or restore guarantee is
implemented by this Send UI branch.

## 7. Currency Selection

The amount selector supports entering DGB or fiat.

Fiat selection follows AppSettingsProvider.selectedCurrency
instead of being hardcoded to USD.

The exchange rate comes from the existing price-ticker system.

Supported fiat codes and their availability depend on the
existing app settings and exchange-rate data.

Expected behavior:

- Users can select coin or fiat amount entry.
- The current wallet's coin ticker is displayed.
- The user's configured fiat code is displayed.
- Switching display modes preserves the intended coin amount.
- Fiat displays normally round to two decimal places.
- Coin calculations retain the wallet's supported precision.
- Unavailable exchange rates should block misleading conversion.

Switching currencies does not change which cryptocurrency
the wallet sends.

Exchange rates are estimates and may update independently
of transaction entry.

## 8. Live Amount Conversion

The form shows a conversion underneath the amount input.

Expected behavior:

- Enter a DGB amount: display its fiat equivalent.
- Enter a fiat amount: display its DGB equivalent.
- Change the amount: refresh the conversion.
- Change DGB/fiat mode: update the displayed value.
- With no amount entered, display the exchange-rate reference.
- The payment remains denominated in DigiByte atomic units.

Important:

The displayed fiat value is informational. Network fees and
the final transaction total must be verified at confirmation.

The current code still uses floating-point values in portions
of its conversion pathway; exact atomic-unit behavior and
rounding boundaries require additional regression tests.

## 9. The All Button

"All" replaces the previous "Empty wallet" label.

The feature fills the amount using the wallet's current
full-balance amount.

It should preserve the current DGB/fiat display choice.

Internally, full-balance selection must remain tied to the
coin balance rather than the rounded fiat display.

Multi-recipient mode does not offer the same single-recipient
All action.

CRITICAL PRE-MERGE TEST:

Verify full-balance sending with transaction fees, dust rules,
and change-output behavior.

Do not assume that displayed balance equals the exact value
receivable after network fees.

Test the final review screen before any actual full-balance send.

## 10. Embedded Amount Keypad

The form uses a Flutter-controlled keypad for amount entry.

The platform's default numeric keypad is not used for this
amount input.

Keypad features:

- Digits 0 through 9.
- Decimal point.
- Backspace.
- Visible Done action.
- Live conversion recalculation.
- Coin and fiat precision constraints.
- No duplicate decimal separator.
- Amount input stays integrated into the Send form.

The keypad should not cover the Send workflow or ad banner.

While the keypad is active, some secondary content is hidden
to preserve vertical space.

After Done, the normal Send action and Advanced Options return.

Revision 4 styling:

- Transparent keypad background.
- Circular keys.
- White numerals.
- Thin semi-transparent white circular borders.
- Dark DigiByte/navy theme retained.
- Backspace uses an outlined icon.
- Touch feedback remains available.

Test with large accessibility text and smaller phone screens.

## 11. Advanced Options

Advanced Options are collapsed during normal sending.

The existing advanced capabilities remain accessible:

- Add or remove additional recipients.
- Navigate between multiple recipients.
- Import recipient information from CSV.
- Enable and edit OP_RETURN transaction metadata.
- Enforce existing metadata length constraints.
- Display the existing metadata warnings.

OP_RETURN is publicly recorded on the blockchain.

An ordinary recipient label is local wallet metadata and
must not be confused with public OP_RETURN data.

All advanced features require dedicated regression testing.

## 12. QR Scanner Changes

The scanner is shared with other QR-enabled screens.

The scanner event stream can emit several frames containing
the same QR code.

Previously, repeated processing could attempt repeated
Navigator.pop operations. This is a plausible explanation
for the observed return to the wallet home screen.

Changes introduced:

- A single-result guard.
- Ignore repeated or empty scan results.
- Cancel the scan subscription after accepting a result.
- Dispose of the QR controller when leaving the scanner.
- Check widget mounted state before using scanner results.
- Maintain Android camera pause/resume handling.

The scanner returns its QR value to the initiating route.

The Send screen parses the returned value and updates
the recipient address.

For payment URIs that include a DGB amount:

- Parse the requested coin amount.
- Use DGB amount entry rather than rounding via fiat cents.
- Preserve the requested amount within coin precision.

URI labels are also supported by the existing parsing path.

IMPORTANT:

The previous navigation issue was not accompanied by a
definitive fatal exception in the supplied Xcode logs.

This scanner lifecycle fix is a likely remedy but requires
repeat testing. The issue is not considered conclusively
resolved until verified.

Because the scanner is shared, test other QR import workflows.

## 13. Existing Transaction Logic

This branch does not intentionally replace:

- Recipient-map construction.
- Wallet address derivation.
- UTXO selection.
- Transaction building.
- Network-fee estimation.
- Change-output creation.
- Transaction signing.
- Transaction broadcasting.
- Authentication requirements.
- Transaction confirmation screen.

The existing confirmation screen remains responsible for
showing transaction values, fees, totals, and recipients.

Review that confirmation screen carefully in both DGB and
fiat modes.

The previous working private-key export fix is separate
and remains on master.

## 14. Development Iterations

Revision 1:

- Compact Send layout.
- Inline Paste and Scan.
- All terminology.
- DGB/fiat selector.
- Advanced Options grouping.
- Remove duplicate QR entry point.

Revision 2:

- Fix incorrect empty-amount validation wording.
- Add an embedded amount keypad.
- Keep the chosen currency when All is selected.
- Restore conversion text.
- Improve spacing near the lower ad area.
- Reduce unnecessary label-counter space.
- Adjust balance-header behavior.

Manual compilation correction:

- Replace an unavailable Flutter MaterialLocalizations
  doneButtonLabel getter with the literal "Done".

Revision 3:

- Support the configured fiat currency.
- Shorten conversion presentation.
- Improve amount-input handling.
- Prevent repeated QR scanner navigation events.
- Improve QR controller/subscription cleanup.
- Avoid rounding QR coin amounts through fiat.
- Improve keypad visibility and touch targets.

Revision 4:

- Replace solid white rectangular keypad buttons.
- Introduce outlined circular keypad buttons.
- White numerals with thin translucent borders.
- Preserve DigiByte's existing colors and styling.

## 15. Tests Performed So Far

Observed during development:

- Flutter analyzer ran after each revision.
- The application built and launched on an iPhone.
- The new Send layout rendered on the device.
- DGB/fiat switching worked in limited manual testing.
- Live conversion updated during manual amount entry.
- The embedded keypad accepted numeric input.
- The circular keypad styling rendered correctly.
- An actual small transaction was reported successful.
- The existing transaction confirmation screen remained usable.
- The application connected to Electrum and synchronized.

These are manual development observations, not a complete
automated test suite.

The latest analyzer run reported 15 warning/info notices
and no Dart analyzer errors.

Warnings include nullability, style, and asynchronous
BuildContext usage. Review before final release.

## 16. Log Review

Supplied Xcode logs show successful application startup
and ongoing Electrum activity.

Observed unrelated or potentially separate messages include:

- Firebase In-App Messaging image HTTP 404 responses.
- AdMob no-fill or ad-process messages.
- iOS networking diagnostics.
- Earlier wallet-storage initialization warnings.

No definitive fatal Dart exception was identified in
the last supplied keypad-build log.

These observations do not establish that all runtime
paths are free of crashes.

Logs can contain addresses, transaction information,
or tokens. Avoid committing raw device logs.

## 17. Required Pre-Merge Regression Checklist

Basic Send:

- [ ] Fresh Send form opens correctly.
- [ ] Normal form requires no unnecessary scrolling.
- [ ] Send button stays separated from advertising.
- [ ] Keyboard Done action restores normal controls.
- [ ] Address Paste works.
- [ ] Address-book suggestions work.
- [ ] Invalid addresses are rejected.
- [ ] Duplicate recipients are handled correctly.
- [ ] Labels can be entered and saved locally.

Keypad:

- [ ] Digits 0-9 work.
- [ ] Decimal point works.
- [ ] Backspace works.
- [ ] Multiple decimal points are prevented.
- [ ] Fiat precision is enforced.
- [ ] DGB fractional precision is enforced.
- [ ] Done returns to the ordinary Send form.
- [ ] Repeated keypad open/close works.
- [ ] Large-text accessibility remains usable.

Currency:

- [ ] DGB mode converts correctly.
- [ ] USD mode converts correctly.
- [ ] At least one non-USD fiat currency works.
- [ ] Configured currency is respected after reopening.
- [ ] Exchange-rate changes refresh the calculation.
- [ ] Missing rates do not produce invalid values.
- [ ] Switching modes does not unexpectedly alter DGB sent.
- [ ] Small-value rounding is checked.

All:

- [ ] All preserves selected display currency.
- [ ] All uses full coin balance internally.
- [ ] Fee deduction is clearly shown.
- [ ] All does not cause an insufficient-fee transaction.
- [ ] Dust and minimum output conditions are handled.
- [ ] Switching currency after All is consistent.
- [ ] Editing after All clears the All-specific state.
- [ ] Multi-recipient interactions are checked.

QR scanning:

- [ ] Plain DGB address QR works.
- [ ] digibyte: URI works.
- [ ] URI with amount works.
- [ ] URI with label works.
- [ ] Duplicate scanner frames do not pop extra screens.
- [ ] Cancelling the scanner returns to Send.
- [ ] Several consecutive scans work.
- [ ] Camera permission denial is handled.
- [ ] Shared scanner workflows still work on other screens.

Advanced:

- [ ] Add recipient works.
- [ ] Delete recipient works.
- [ ] Switching recipients retains entered values.
- [ ] CSV import works with valid data.
- [ ] Malformed CSV is handled safely.
- [ ] OP_RETURN metadata works.
- [ ] OP_RETURN size limits work.
- [ ] Public metadata warning remains visible.

Transaction and platform:

- [ ] Confirmation address is correct.
- [ ] Confirmation amount is correct.
- [ ] Fees and total are correct.
- [ ] Authentication behavior remains unchanged.
- [ ] A small real transaction succeeds.
- [ ] The app handles transaction failure gracefully.
- [ ] Ad visible and unavailable states both render correctly.
- [ ] iPhone portrait and smaller screens are checked.
- [ ] Android build and scanner receive smoke testing.
- [ ] UI survives larger accessibility text settings.

## 18. Known Outstanding Work

- More complete QR scanner regression testing.
- Full-balance and fee/dust edge-case verification.
- Review lingering analyzer warnings.
- Review accessibility and responsive layout behavior.
- Verify all supported fiat settings.
- Verify translations beyond English.
- Review advanced recipient and CSV behavior.
- Assess ad placement on different screen sizes.
- Design an independent address-label restoration feature.
- Confirm Android compatibility.

Do not mark these complete without corresponding test evidence.

## 19. Merge Criteria

Do not merge this branch into master until:

1. Send functionality has passed regression testing.
2. QR navigation behaves correctly over repeated scans.
3. Coin/fiat conversion and All fee behavior are verified.
4. Advanced Options remain functional.
5. The iOS build passes and Android is smoke-tested.
6. No new blocking analyzer errors remain.
7. The final code diff receives review.
8. The user explicitly approves the merge.

Label recovery may be tracked as separate work, but its
current limitation must remain documented.

## 20. Git and Release Management

Branch: feat/send-ui-refresh-20261018

This development commit must be pushed to the feature branch
only. Do not modify or merge master in this operation.

The locally modified Xcode project file:

ios/Runner.xcodeproj/project.pbxproj

is intentionally excluded because its local differences
were not required for this feature commit.

No application build-number bump is required merely to
preserve this work-in-progress development checkpoint.

Review release versioning separately before distribution.
