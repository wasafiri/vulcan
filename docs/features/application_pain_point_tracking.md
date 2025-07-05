# Application Pain Point Tracking

## Purpose

This feature tracks the last step visited by constituents who start an application but do not complete the submission (i.e., leave it in `draft` status). This data helps identify potential "pain points" or areas in the application form where users most frequently abandon the process.

## Implementation Details

1.  **Database:**
    *   A `last_visited_step` (type: `string`) column on the `applications` table tracks the last visited step.

2.  **Tracking Mechanism:**
    *   The `ConstituentPortal::ApplicationsController#autosave_field` action is leveraged.
    *   When an application or user field is successfully autosaved for a draft application, the `last_visited_step` column on the `Application` record updates with the name of the field that was just saved.
    *   This update happens within the `autosave_user_field` and `autosave_application_field` private methods using `update_column` for efficiency (skipping validations and callbacks).

3.  **Data Analysis:**
    *   The `Application.pain_point_analysis` class method in the `Application` model (`app/models/application.rb`) queries applications with `status: :draft`, filters out those where `last_visited_step` is `nil` or blank, groups the results by `last_visited_step`, counts the occurrences in each group, and orders the results by count descending.
    *   It returns a hash where keys are the `last_visited_step` field names and values are the counts.
    *   A corresponding `:draft` scope is also available on the model.

4.  **Admin Interface:**
    *   **Route:** The route `GET /admin/application_analytics/pain_points` is defined in `config/routes.rb`.
    *   **Controller:** The `Admin::ApplicationAnalyticsController` (`app/controllers/admin/application_analytics_controller.rb`) has a `pain_points` action that calls `Application.pain_point_analysis` and stores the result in `@analysis_results`.
    *   **View:** The view `app/views/admin/application_analytics/pain_points.html.erb` displays the `@analysis_results` in a table, showing the humanized step name, the raw field name, and the drop-off count.
    *   **Link:** A link to the "Pain Point Analysis" page is available on the Admin Dashboard (`app/views/admin/applications/index.html.erb`) under the "Operations" section.

5.  **Testing:**
    *   Controller tests (`test/controllers/constituent_portal/applications_controller_autosave_test.rb`) verify that `last_visited_step` is updated correctly during autosave for both application and user fields.
    *   Model tests (`test/models/application_test.rb`) cover the `:draft` scope and the `pain_point_analysis` method.
    *   Admin controller tests (`test/controllers/admin/application_analytics_controller_test.rb`) cover the `pain_points` action.

## How to Interpret Results

The "Application Pain Point Analysis" page in the admin dashboard lists the application form fields (steps) where users last saved data before abandoning their draft applications.

*   **Higher counts** for a specific step suggest that users might be encountering difficulties, confusion, or barriers at that point in the application process.
*   Analyze the steps with the highest drop-off rates to identify areas for potential improvement in the user experience, form clarity, or required information.
*   The raw field name is included in parentheses for technical reference.
