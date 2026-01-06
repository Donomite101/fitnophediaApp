# Workout Dashboard Redesign Plan

## Objective
Create a high-performance, action-oriented Workout Dashboard that answers "What should I do right now?" immediately, minimizing clutter and maximizing engagement.

## Core Philosophy
**"Action over Options"** - The user shouldn't hunt for their workout. It should be the only obvious choice.

## UI Structure & Components

### 1. Header & Consistency Signals
-   **Left:** Greeting + "Athlete Name".
-   **Right:** 🔥 **Streak Counter** (e.g., "12 Day Streak") & **Recovery Score** (e.g., "85% Ready").
-   **Style:** Minimalist, using neon accents for status.

### 2. The "Today" Card (Hero Section)
-   **Prominence:** Takes up top 40% of the screen.
-   **Content:**
    -   **Title:** "Push Day: Chest & Triceps" (Dynamic based on schedule).
    -   **Meta:** "45 Mins" • "Hypertrophy" • "Gym Required".
    -   **Smart Note:** "⚠️ Low sleep detected. Volume reduced by 10%." (Mocked logic for now).
    -   **Primary CTA:** Giant "START WORKOUT" button.
-   **Background:** Dynamic gradient or abstract 3D shape representing muscle group.

### 3. Smart Alternatives (Just below Hero)
-   **Context:** "Can't make it?"
-   **Options (Pill Buttons):**
    -   "⚡ Express (15m)"
    -   "🏠 Home Version"
    -   "🔄 Swap Day"

### 4. Program Roadmap
-   **Visual:** A horizontal timeline of the current week (M T W T F S S).
-   **Status:**
    -   **Past:** Checked off (Green).
    -   **Today:** Highlighted/Pulsing.
    -   **Future:** Dimmed.
-   **Progress:** "Week 4 of 12" linear progress bar.

### 5. Coach Insight (Dismissible)
-   **Content:** "Tip: You missed yesterday. Let's crush today to keep the streak alive!"
-   **Style:** Subtle glassmorphism banner, distinct from the workout card.

### 6. Secondary Actions (The "Drawer")
-   **Location:** Bottom of the screen, less visual weight.
-   **Items:**
    -   📚 Exercise Library
    -   ➕ Custom Workout
    -   ⚙️ Program Settings

## Technical Implementation Steps

1.  **Refactor `WorkoutHomeScreen`:** Clear existing layout.
2.  **Create `TodayWorkoutCard` Widget:** Encapsulate the hero logic.
3.  **Create `ProgramRoadmap` Widget:** Implement the week view logic.
4.  **Mock Data Layer:** Since we don't have a full program engine yet, we will mock the "Active Program" and "Schedule" to demonstrate the UI.
5.  **Integrate:** Assemble components into the main screen with `SingleChildScrollView`.

## Next Steps
Once you approve this plan, I will proceed to code the `WorkoutHomeScreen` following this exact structure.
