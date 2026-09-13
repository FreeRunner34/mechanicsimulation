#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
imported = (root / "MasterMechanic" / "ImportedBase44Cases.swift").read_text()
models = (root / "MasterMechanic" / "Models.swift").read_text()
views = (root / "MasterMechanic" / "Views.swift").read_text()
extra = (root / "MasterMechanic" / "ExtraASEQuestions.swift").read_text()
storekit_path = root / "MasterMechanic" / "MasterMechanic.storekit"

block = imported.split('private static let rawSeeds = """', 1)[1].split('"""', 1)[0]
rows = [line for line in block.splitlines() if '¦' in line]
assert len(rows) == 80, f"Expected 80 migrated ROs, found {len(rows)}"
ids = []
for number, row in enumerate(rows, 1):
    fields = row.split('¦')
    assert len(fields) == 9, f"RO row {number} has {len(fields)} fields instead of 9"
    assert fields[1] in {'E','A','T','S','M','D'}, f"RO row {number} has bad difficulty {fields[1]!r}"
    int(fields[4])
    assert fields[3].strip(), f"RO row {number} is missing vehicle"
    assert fields[5].strip(), f"RO row {number} is missing complaint"
    assert fields[7].strip(), f"RO row {number} is missing root cause"
    assert fields[8].strip(), f"RO row {number} is missing repair"
    ids.append(fields[0])
assert len(ids) == len(set(ids)), "Migrated RO IDs are not unique"

assert "example.com" not in models, "Placeholder production URL remains in Models.swift"
assert "ImportedCaseHook.swift" not in (root / "MasterMechanic.xcodeproj" / "project.pbxproj").read_text()
assert not (root / "MasterMechanic" / "ImportedCaseHook.swift").exists(), "Legacy global array operator hook still exists"
assert '$6.99 / month' not in views, "Hard-coded storefront price remains in the UI"
assert "practiceTest(area:area.0, questionCount:20)" in views, "Training view is not using randomized practice tests"

config = json.loads(storekit_path.read_text())
products = list(config.get("products", []))
for group in config.get("subscriptionGroups", []):
    products.extend(group.get("subscriptions", []))
product_ids = {item.get("productID") for item in products}
expected_product = "com.freerunner34.mastermechanic.pro.monthly"
assert expected_product in product_ids, "Local StoreKit product ID does not match app code"
unlock = next(item for item in products if item.get("productID") == expected_product)
assert unlock.get("type") == "NonConsumable", "Pro must be configured as a non-consumable one-time purchase"

base_questions = len(re.findall(r'\n\s*q\("a[1-8]"', (root / "MasterMechanic" / "AppData.swift").read_text()))
scenario_count = extra.count('s("')
assert base_questions >= 8, f"Expected at least eight built-in ASE questions, found {base_questions}"
assert scenario_count >= 160, f"Expected at least 160 ASE concept scenarios, found {scenario_count}"
assert 'for variant in 0..<3' in extra, "ASE bank no longer generates three variants per concept"

assert (root / "PRIVACY.md").exists()
assert (root / "SUPPORT.md").exists()
assert (root / "MasterMechanicTests" / "MasterMechanicTests.swift").exists()
assert (root / "MasterMechanic.xcodeproj" / "xcshareddata" / "xcschemes" / "MasterMechanic.xcscheme").exists()

icon_contents = json.loads((root / "MasterMechanic" / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json").read_text())
has_icon_filename = any(item.get("filename") for item in icon_contents.get("images", []))
assert has_icon_filename, "Final 1024x1024 App Store icon is not assigned"

print(f"Validated {len(rows)} migrated repair orders")
print(f"Validated {base_questions + scenario_count * 3}+ ASE-style question variants")
print("Validated one-time StoreKit Pro unlock, production URLs, randomized practice tests, and app icon")
