# New Project Creation

Execute the adaptive template learning system to create a new project from templates.

## Instructions

1. Run the template engine script: `~/.claude/scripts/template-engine.sh`
2. The script will:
   - Display available templates with confidence scores
   - Guide you through variable collection
   - Preview the project structure
   - Create the project with substituted variables
   - Show next steps for project setup

3. After the script completes:
   - Navigate to the created project directory
   - Follow the post-creation steps displayed
   - Initialize git if needed: `git init && git add . && git commit -m "Initial commit from template"`
   - Report success to the user with project location and next steps

## Available Templates

- **swift-ios-app**: SwiftUI iOS/iPadOS application with SwiftData
- **node-express-api**: Node.js Express API with CORS and environment config
- **bash-automation**: Shell script automation template (to be created)

## Post-Execution

After running the template engine, provide:
1. Confirmation of project creation
2. Project location
3. Summary of files created
4. Next steps from the template's post-creation instructions
5. Suggestions for customization

Execute the template engine now to create a new project.
