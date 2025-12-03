---
description: Search playwright scraper data and documentation in COOLFORK project
tags: [playwright, scraper, data, search]
---

You are searching the playwright scraper project data in the COOLFORK directory.

**Instructions:**

1. **First, ask the user to choose a category** using AskUserQuestion (max 4 options, so split into two questions):

   **Question 1:**
   - Audio Excel Database - Search audio equipment, PA systems, microphones, processing
   - Video Excel Database - Search cameras, projectors, lenses, screens, video processing
   - Lighting Excel Database - Search fixtures, consoles, LED, moving lights, dimmers
   - More categories... - See Rigging, Networking, or search all categories

   **If user selects "More categories...", ask Question 2:**
   - Rigging Excel Database - Search truss, motors, chain hoists, rigging hardware
   - Networking Excel Database - Search network switches, wireless systems, control networks
   - All Categories - Search across all equipment categories

2. **Then ask for the search term** if not provided in {{prompt}}

3. **Run the search** within the selected category:
   ```bash
   # For specific category:
   $HOME/.claude/scripts/playwright-search.sh "<search_term>" 10 "/Volumes/DevDrive/Projects/COOLFORK/<Category> Excel Database"

   # For all categories:
   $HOME/.claude/scripts/playwright-search.sh "<search_term>" 10
   ```

4. **Present the results:**
   - Show which files matched the search query
   - Display file types (documentation, logs, scraped data, reports)
   - Show relevance scores and matching content previews
   - Provide full file paths for deeper inspection

5. **Summarize findings:**
   - What type of data was found (docs, logs, scraped data, etc.)
   - Key insights from the matching content
   - Suggest related searches if relevant

**What This Does:**
- Searches documentation files (.md) in the selected category
- Searches log files for debugging and error information
- Searches scraped data (.json files) from playwright runs
- Searches test scripts and implementation notes
- Ranks results by relevance score

**Search Scope:**
- Location: `/Volumes/DevDrive/Projects/COOLFORK`
- Categories: Audio, Video, Lighting, Rigging, Networking
- File types: Markdown, JSON, logs, JavaScript/TypeScript

**Category Details:**
- **Audio**: Audio equipment, PA systems, microphones, processing
- **Video**: Cameras, projectors, lenses, screens, video processing
- **Lighting**: Fixtures, consoles, LED, moving lights, dimmers
- **Rigging**: Truss, motors, chain hoists, rigging hardware
- **Networking**: Network switches, wireless systems, control networks

**Usage Examples:**
- `/goplaywright` - Interactive: choose category, then search
- `/goplaywright fullcompass` - Will ask which category to search
- Search terms: brand names, product types, vendor names, errors

**Output Format:**
1. Category selected and search term used
2. Number of matches found
3. Top results with file types, paths, and content previews
4. Suggestions for further exploration
