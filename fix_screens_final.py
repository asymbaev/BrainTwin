#!/usr/bin/env python3
"""
Systematically fix all onboarding screens by adding ScrollView wrappers
"""

def find_closing_brace(lines, start_idx):
    """Find the matching closing brace for a VStack"""
    depth = 1
    i = start_idx + 1
    while i < len(lines) and depth > 0:
        depth += lines[i].count('{')
        depth -= lines[i].count('}')
        if depth == 0:
            return i
        i += 1
    return -1

def fix_screen(lines, screen_name, start_line):
    """Fix a single screen by adding ScrollView wrapper"""
    # Find "private var {screen_name}: some View {"
    view_decl_idx = -1
    for i in range(start_line, min(start_line + 5, len(lines))):
        if f'private var {screen_name}: some View' in lines[i]:
            view_decl_idx = i
            break

    if view_decl_idx == -1:
        return False

    # Next line should be "        VStack(spacing: 0) {"
    vstack_idx = view_decl_idx + 1
    if vstack_idx >= len(lines) or 'VStack(spacing: 0)' not in lines[vstack_idx]:
        return False

    # Find where VStack closes
    vstack_close_idx = find_closing_brace(lines, vstack_idx)
    if vstack_close_idx == -1:
        return False

    # Insert ScrollView opening after "some View {"
    lines[vstack_idx] = '        ScrollView(.vertical, showsIndicators: false) {\n            VStack(spacing: 0) {\n'

    # Add 4 spaces to all lines inside VStack (from vstack_idx+1 to vstack_close_idx-1)
    for i in range(vstack_idx + 1, vstack_close_idx):
        if lines[i].startswith('            '):  # 12 spaces
            lines[i] = '    ' + lines[i]  # Add 4 spaces

    # At vstack_close_idx, change "        }" to "            }\n        }"
    # (close VStack with proper indent, then close ScrollView)
    old_close = lines[vstack_close_idx]
    if old_close.strip() == '}':
        indent = len(old_close) - len(old_close.lstrip())
        if indent == 8:  # Should be 8 spaces for VStack close
            lines[vstack_close_idx] = '            }\n        }\n'

    return True

# Read file
with open('BrainTwin/OnboardingView.swift', 'r') as f:
    lines = f.readlines()

# Screens to fix (already fixed: screen0_WelcomeIntro)
screens_to_fix = [
    ('screen0_5_ValueProp', 580),
    ('screen0_75_MoodCheck', 660),
    ('screen1_AgeCollection', 900),
    ('screen2_GoalSelection', 995),
    ('screen3_StruggleSelection', 1150),
    ('screen_DidYouKnow', 1280),
    ('screen4_TimeSelection', 1525),
]

for screen_name, approx_line in screens_to_fix:
    success = fix_screen(lines, screen_name, approx_line)
    if success:
        print(f"✅ Fixed {screen_name}")
    else:
        print(f"❌ Failed to fix {screen_name}")

# Write back
with open('BrainTwin/OnboardingView.swift', 'w') as f:
    f.writelines(lines)

print("\n✅ All screens processed")
