// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Tooling;

using System.PerformanceProfile;

/// <summary>
/// List for performance profiles generated by profile schedules
/// </summary>
page 1931 "Performance Profile List"
{
    Caption = 'Performance Profiles';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    AboutTitle = 'About performance profiles';
    AboutText = 'View the profiles generated by profiler schedules. The profiler uses sampling technology, so the results may differ slightly between recordings of the same scenario.';
    Editable = false;
    SourceTable = "Performance Profiles";

    layout
    {
        area(Content)
        {
            repeater(Profiles)
            {
                field("Start Time"; Rec."Starting Date-Time")
                {
                    Caption = 'Start Time';
                    ToolTip = 'Specifies the time the profile was started.';
                    AboutText = 'The time the profile was started.';
                }
                field("User Name"; Rec."User Name")
                {
                    Caption = 'User Name';
                    ToolTip = 'Specifies the name of the user that was profiled.';
                    AboutText = 'The username of the user that was profiled.';
                }
                field(Activity; ActivityType)
                {
                    Caption = 'Activity Type';
                    ToolTip = 'Specifies the type of activity for which the schedule is created.';
                    AboutText = 'The type of activity for which the schedule is created.';
                }
                field("Activity Description"; Rec."Activity Description")
                {
                    Caption = 'Activity Description';
                    ToolTip = 'Specifies a short description of the activity that was profiled.';
                    AboutText = 'A description of the activity that was profiled.';
                }
                field(ActivityDuration; Rec."Activity Duration")
                {
                    Caption = 'Activity Duration';
                    ToolTip = 'Specifies the duration of the recorded activity including system operations and waiting for input.';
                    AboutText = 'The duration of the recorded activity including system operations and waiting for input.';
                }
                field(ALExecutionTime; Rec.Duration)
                {
                    Caption = 'AL Execution Duration';
                    ToolTip = 'Specifies the total duration of the sampled AL code in the recorded activity. This measurement is approximate as it depends on the selected sampling frequency.';
                    AboutText = 'The duration of the sampled AL code in this activity.';
                }
                field("Sql Call Duration"; Rec."Sql Call Duration")
                {
                    Caption = 'Duration of captured SQL calls';
                    ToolTip = 'Specifies the duration of SQL calls during the activity that was profiled in milliseconds.';
                    AboutText = 'The duration of SQL calls during the activity that was profiled.';
                }
                field("Sql Call Number"; Rec."Sql Statement Number")
                {
                    Caption = 'Number of SQL Calls';
                    ToolTip = 'Specifies the number of SQL calls during the activity that was profiled in milliseconds.';
                    AboutText = 'The number of SQL calls during the activity that was profiled.';
                }
                field("Http Call Duration"; Rec."Http Call Duration")
                {
                    Caption = 'Duration of Http Calls';
                    ToolTip = 'Specifies the duration of the http calls during the activity that was profiled in milliseconds.';
                    AboutText = 'The duration of external http calls during the activity that was profiled.';
                }
                field("Http Call Number"; Rec."Http Call Number")
                {
                    Caption = 'Number of Http Calls';
                    ToolTip = 'Specifies the number of http calls during the activity that was profiled.';
                    AboutText = 'The number of external http calls during the activity that was profiled.';
                }
                field("Platform Call Duration"; PlatformCallDuration)
                {
                    Caption = 'Duration of Platform Calls';
                    ToolTip = 'Specifies the duration of platform calls during the activity that was profiled in milliseconds.';
                    AboutText = 'The duration of platform calls during the activity that was profiled.';
                }
                field("Correlation ID"; Rec."Activity ID")
                {
                    Caption = 'Correlation ID';
                    ToolTip = 'Specifies the ID of the activity that was profiled.';
                    AboutText = 'The ID of the activity that was profiled.';
                }
                field("Client Session ID"; Rec."Client Session ID")
                {
                    Caption = 'Client Session ID';
                    ToolTip = 'Specifies the ID of the client session that was profiled.';
                    AboutText = 'The ID of the client session that was profiled.';
                }
#if not CLEAN27
                field("Schedule ID"; Rec."Schedule ID")
                {
                    Caption = 'Schedule ID';
                    ToolTip = 'Specifies the ID of the schedule that was used to profile the activity.';
                    AboutText = 'The ID of the schedule that was used to profile the activity.';
                    TableRelation = "Performance Profile Scheduler"."Schedule ID";
                    DrillDown = true;
                    Visible = false;
                    ObsoleteReason = 'This field is obsolete.';
                    ObsoleteState = Pending;
                    ObsoleteTag = '27.0';

                    trigger OnDrillDown()
                    var
                        PerfProfileSchedule: Record "Performance Profile Scheduler";
                        PerfProfileScheduleCard: Page "Perf. Profiler Schedule Card";
                    begin
                        if not PerfProfileSchedule.Get(Rec."Schedule ID") then
                            exit;

                        PerfProfileScheduleCard.SetRecord(PerfProfileSchedule);
                        PerfProfileScheduleCard.Run();
                    end;
                }
#endif
                field("Schedule Description"; ScheduleDescription)
                {
                    ApplicationArea = All;
                    Caption = 'Schedule Description';
                    ToolTip = 'Specifies the description of the schedule that was used to profile the activity.';
                    DrillDown = true;

                    trigger OnDrillDown()
                    var
                        PerfProfileSchedule: Record "Performance Profile Scheduler";
                        PerfProfileScheduleCard: Page "Perf. Profiler Schedule Card";
                    begin
                        if not PerfProfileSchedule.Get(Rec."Schedule ID") then
                            exit;

                        PerfProfileScheduleCard.SetRecord(PerfProfileSchedule);
                        PerfProfileScheduleCard.Run();
                    end;
                }
            }
        }
    }

    actions
    {
        area(Promoted)
        {
            actionref(OpenProfiles; "Open Profile")
            {
            }

            actionref(Refresh; RefreshPage)
            {
            }

            actionref(DownloadProfile; Download)
            {
            }
        }

        area(Navigation)
        {
            action("Open Profile")
            {
                ApplicationArea = All;
                Image = Setup;
                Caption = 'Open Profile';
                ToolTip = 'Open profiles for the scheduled session';
                Enabled = Rec."Activity ID" <> '';
                ShortcutKey = 'Return';

                trigger OnAction()
                var
                    ProfilerPage: Page "Performance Profiler";
                    ProfileInStream: InStream;
                begin
                    Rec.CalcFields(Profile);
                    Rec.Profile.CreateInStream(ProfileInStream);
                    ProfilerPage.SetData(ProfileInStream);
                    ProfilerPage.Run();
                end;
            }

            action(RefreshPage)
            {
                ApplicationArea = All;
                Image = Refresh;
                Caption = 'Refresh';
                ToolTip = 'Refresh the profiles for the schedule.';

                trigger OnAction()
                begin
                    Update();
                end;
            }

            action(Download)
            {
                ApplicationArea = All;
                Image = Download;
                Enabled = Rec."Activity ID" <> '';
                Caption = 'Download';
                ToolTip = 'Download the performance profile file.';

                trigger OnAction()
                var
                    SampPerfProfilerImpl: Codeunit "Sampling Perf. Profiler Impl.";
                    FileName: Text;
                    ProfileInStream: InStream;
                begin
                    FileName := StrSubstNo(ProfileFileNameTxt, Rec."Activity ID", Rec."Client Session ID") + ProfileFileExtensionTxt;
                    Rec.CalcFields(Profile);
                    Rec.Profile.CreateInStream(ProfileInStream);
                    SampPerfProfilerImpl.DownloadData(FileName, ProfileInStream);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        RecordRef: RecordRef;
    begin
        Rec.SetAutoCalcFields("User Name", "Client Type");
        RecordRef.GetTable(Rec);
        ScheduledPerfProfilerImpl.FilterUsers(RecordRef, UserSecurityId(), false);
        RecordRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    var
    begin
        this.MapClientTypeToActivityType();
        PlatformCallDuration := this.ComputePlatformCallDuration();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        this.MapClientTypeToActivityType();
        ScheduleDescription := ScheduleDisplayName();
        PlatformCallDuration := this.ComputePlatformCallDuration();
    end;

    local procedure MapClientTypeToActivityType()
    begin
        Rec.CalcFields(Rec."Client Type");
        PerfProfActivityMapper.MapClientTypeToActivityType(rec."Client Type", ActivityType);
    end;

    local procedure ScheduleDisplayName(): Text
    var
        PerformanceProfileScheduler: Record "Performance Profile Scheduler";
    begin
        if PerformanceProfileScheduler.Get(Rec."Schedule ID") then
            exit(PerformanceProfileScheduler.Description);
    end;

local procedure ComputePlatformCallDuration(): Duration
    var
        diff: Duration;
    begin
        diff := Rec.Duration + Rec."Sql Call Duration" + Rec."Http Call Duration";
        if Rec."Activity Duration" >= diff then
            exit(Rec."Activity Duration" - diff);

        exit(0);
    end;

    var
        PerfProfActivityMapper: Codeunit "Perf. Prof. Activity Mapper";
        ScheduledPerfProfilerImpl: Codeunit "Scheduled Perf. Profiler Impl.";
        ActivityType: Enum "Perf. Profile Activity Type";
        ScheduleDescription: Text;
        PlatformCallDuration: Duration;
        ProfileFileNameTxt: Label 'PerformanceProfile_Activity%1_Session%2', Locked = true;
        ProfileFileExtensionTxt: Label '.alcpuprofile', Locked = true;
}