#if not CLEAN27
// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Feedback;

/// <summary>
/// Provides methods to connect to CES.
/// </summary>
codeunit 9260 "Customer Experience Survey"
{
    Access = Public;
    InherentEntitlements = X;
    InherentPermissions = X;
    ObsoleteReason = 'This module is no longer used.';
    ObsoleteState = Pending;
    ObsoleteTag = '27.0';

    /// <summary>
    /// Pushes a new event entry to the CES back-end for the current user.
    /// </summary>
    /// <param name="EventName">Name of the event to be registered.</param>
    /// <returns>Returns true if the request was successful.</returns>
    procedure RegisterEvent(EventName: Text): Boolean
    begin
    end;

#pragma warning disable AA0150
    /// <summary>
    /// Gets the eligibility of the current user for the indicated survey. Making this API call resets the eligibility flag (this avoids double prompting).
    /// </summary>
    /// <param name="SurveyName">Name of the survey.</param>
    /// <param name="FormsProId">ID of the survey.</param>
    /// <param name="FormsProEligibilityId">This ID is used to render survey.</param>
    /// <param name="IsEligible">True means that the user is eligible for prompting, and false means the user is not eligible and should not be prompted.</param>
    /// <returns>Returns true if the request was successful.</returns>
    procedure GetEligibility(SurveyName: Text; var FormsProId: Text; var FormsProEligibilityId: Text; var IsEligible: Boolean): Boolean
    begin
    end;

    /// <summary>
    /// Push a new event entry to the CES back-end, and get the eligibility of a given user for the indicated survey. This endpoint combines the functionality of the above 2 endpoints (adding an event and checking user eligibility).
    /// </summary>
    /// <param name="SurveyName">Name of the survey.</param>
    /// <param name="FormsProId">ID of the survey.</param>
    /// <param name="FormsProEligibilityId">This ID is used to render survey.</param>
    /// <returns>Returns true if the request was successful.</returns>
    procedure RegisterEventAndGetEligibility(EventName: Text; SurveyName: Text; var FormsProId: Text; var FormsProEligibilityId: Text; var IsEligible: Boolean): Boolean
    begin
    end;
#pragma warning restore AA0150

    /// <summary>
    /// Returns the details for a single survey
    /// </summary>
    /// <param name="SurveyName">Name of the survey.</param>
    /// <param name="CustomerExperienceSurvey">Survey record with details.</param>
    /// <returns>Returns true if the request was successful.</returns>
    procedure GetSurvey(SurveyName: Text; var CustomerExperienceSurvey: Record "Customer Experience Survey"): Boolean
    begin
    end;

    /// <summary>
    /// Renders a given survey
    /// </summary>
    /// <param name="SurveyName">Name of the survey.</param>
    /// <param name="FormsProEligibilityId">This ID is used to render survey.</param>
    /// <param name="Locale">Survey localization.</param>
    procedure RenderSurvey(SurveyName: Text; FormsProId: Text; FormsProEligibilityId: Text)
    begin
    end;
}
#endif