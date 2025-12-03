---
description: Run Ruby script to add missing files to Xcode project
---

You need to add files that exist on the filesystem but are not in the Xcode project.

## CRITICAL: Use the xcodeproj gem

The Ruby script MUST use the `xcodeproj` gem (already installed). This is the CocoaPods dependency that properly handles Xcode project files.

## Step 1: Identify the Project

First, find the `.xcodeproj` file and identify:
1. The project path (e.g., `$HOME/4Techz/4Techz/4Techz.xcodeproj`)
2. The target name (check inside project for exact name like `FourTechz`, `4Techz`, `PMNotes App`, etc.)
3. The group structure in the project

## Step 2: Find Missing Files

Compare files on disk vs files in the Xcode project. Look for `.swift` files that exist in the filesystem but aren't in the project.

## Step 3: Run the Ruby Script

Use this exact pattern - DO NOT deviate:

```ruby
#!/usr/bin/env ruby
require 'xcodeproj'

# EXAMPLES OF VALID PROJECT PATHS:
# project_path = '$HOME/4Techz/4Techz/4Techz.xcodeproj'
# project_path = '$HOME/PMNotesApp/PMNotes App/PMNotes App.xcodeproj'

project_path = 'FULL_PATH_TO_XCODEPROJ'  # <- MUST be absolute path
project = Xcodeproj::Project.open(project_path)

# EXAMPLES OF PARENT PATHS (the group hierarchy in Xcode):
# parent_path = '4Techz/Features'
# parent_path = '4Techz/Models'
# parent_path = 'PMNotes App/Views'

parent_path = 'GROUP_PATH'  # <- Path in Xcode's group structure
group_name = 'NEW_OR_EXISTING_GROUP'
subgroup_name = 'SUBGROUP_NAME'  # e.g., 'Views', 'Models', 'ViewModels'

# Find parent group
parent_group = project.main_group.find_subpath(parent_path, false)
abort "Parent group '#{parent_path}' not found" if parent_group.nil?

# Create or find main group
main_group = parent_group.find_subpath(group_name, false)
main_group ||= parent_group.new_group(group_name, group_name)

# Create or find subgroup
sub_group = main_group.find_subpath(subgroup_name, false)
sub_group ||= main_group.new_group(subgroup_name, subgroup_name)

# EXAMPLES OF TARGET NAMES (must match exactly):
# target = project.targets.find { |t| t.name == 'FourTechz' }
# target = project.targets.find { |t| t.name == '4Techz' }
# target = project.targets.find { |t| t.name == 'PMNotes App' }

target = project.targets.find { |t| t.name == 'TARGET_NAME' }
abort "Target not found" if target.nil?

# Files to add - USE FULL ABSOLUTE PATHS
files = [
  '$HOME/path/to/File1.swift',
  '$HOME/path/to/File2.swift',
]

files.each do |filepath|
  filename = File.basename(filepath)
  file_ref = sub_group.new_reference(filepath)
  file_ref.last_known_file_type = 'sourcecode.swift'
  file_ref.source_tree = '<group>'
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added: #{filename}"
end

project.save
puts "Project saved successfully"
```

## Key Points - READ THESE:

1. **xcodeproj gem** - Always use `require 'xcodeproj'`
2. **Absolute paths** - Project path must be absolute (start with `/Users/...`)
3. **new_group(name, path)** - Creates group with filesystem path
4. **new_reference(filepath)** - Adds file reference
5. **source_tree = '<group>'** - Makes path relative to parent group
6. **target.source_build_phase.add_file_reference** - Required for compilation

## Common Project Locations:

| Project | Path | Target Name |
|---------|------|-------------|
| 4Techz | `$HOME/4Techz/4Techz/4Techz.xcodeproj` | `FourTechz` |
| PMNotes | `$HOME/PMNotesApp/PMNotes App/PMNotes App.xcodeproj` | `PMNotes App` |

## To Find Target Name:

```bash
grep -o 'name = "[^"]*"' /path/to/project.pbxproj | head -20
```

Or in Ruby:
```ruby
project.targets.each { |t| puts t.name }
```

## After Running:

1. Open Xcode
2. Verify files appear in the correct groups
