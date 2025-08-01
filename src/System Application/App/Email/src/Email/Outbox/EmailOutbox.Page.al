// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Email;

/// <summary>
/// Displays information about email that are queued for sending.
/// </summary>
page 8882 "Email Outbox"
{
    PageType = List;
    Caption = 'Email Outbox';
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Email Outbox";
    SourceTableTemporary = true;
    AdditionalSearchTerms = 'draft email';
    Permissions = tabledata "Email Outbox" = rd;
    RefreshOnActivate = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    Extensible = true;

    layout
    {
        area(Content)
        {
            repeater(Outbox)
            {
                field(Desc; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the description of email.';

                    trigger OnDrillDown()
                    var
                        EmailEditor: Codeunit "Email Editor";
                    begin
                        RefreshOutbox := true;

                        EmailEditor.Open(Rec, false);
                    end;
                }

                field(Connector; Rec.Connector)
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Specifies the extension that will be used to send the email.';
                }

                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the email job status.';
                }

                field(Error; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the email error message.';
                }

                field(Sender; Rec.Sender)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who triggered this email to be sent.';
                }

                field(SentFrom; Rec."Send From")
                {
                    ApplicationArea = All;
                    Caption = 'Sent From';
                    ToolTip = 'Specifies the email address that this email was sent from.';

                    trigger OnDrillDown()
                    begin
                        ShowAccountInformation();
                    end;
                }

                field("Date Queued"; Rec."Date Queued")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date when this email was queued up to be sent.';
                }

                field("Date Failed"; Rec."Date Failed")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date when this email failed to send.';
                }

                field("Date Sending"; Rec."Date Sending")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date when this email is scheduled for sending.';
                }

                field("Retry No."; Rec."Retry No.")
                {
                    Caption = 'Attempt No.';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total number of sending attempts for this email.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(ShowError)
            {
                ApplicationArea = All;
                Image = Error;
                Caption = 'Show Error';
                ToolTip = 'Show Error.';
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Enabled = FailedStatus or HasRetryDetail;

                trigger OnAction()
                begin
                    Message(Rec."Error Message");
                end;
            }

            action(ShowErrorCallStack)
            {
                ApplicationArea = All;
                Image = ShowList;
                Caption = 'Investigate Error';
                ToolTip = 'View technical details about the error callstack to troubleshoot email errors.';
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Enabled = FailedStatus or HasRetryDetail;

                trigger OnAction()
                begin
                    Message(EmailImpl.FindLastErrorCallStack(Rec.Id));
                end;
            }
            action(ShowSourceRecord)
            {
                ApplicationArea = All;
                Image = GetSourceDoc;
                Caption = 'Show Source';
                ToolTip = 'Open the page from where the email was sent.';
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Enabled = HasSourceRecord;

                trigger OnAction()
                begin
                    EmailImpl.ShowSourceRecord(Rec."Message Id");
                end;
            }
            action(CancelRetry)
            {
                ApplicationArea = All;
                Image = Cancel;
                Caption = 'Cancel Sending';
                ToolTip = 'Cancel the sending of the email.';
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Enabled = true;

                trigger OnAction()
                var
                    EmailRetryImpl: Codeunit "Email Retry Impl.";
                begin
                    if not EmailRetryImpl.CancelRetryByMessageId(Rec."Message Id") then
                        Error(CannotCancelRetryMsg);
                    Message(CancelSendSuccessMsg);
                    CurrPage.Update(false);
                end;
            }
            action(ShowRetryDetail)
            {
                ApplicationArea = All;
                Image = ShowList;
                Caption = 'Attempt Detail';
                ToolTip = 'View the attempt detail of the email.';
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Enabled = HasRetryDetail;

                trigger OnAction()
                var
                    EmailRetryDetailRec: Record "Email Retry";
                begin
                    EmailRetryDetailRec.SetRange("Message Id", Rec."Message Id");
                    PAGE.RunModal(PAGE::"Email Retry Detail", EmailRetryDetailRec);
                end;
            }
        }

        area(Processing)
        {
            action(SendEmail)
            {
                ApplicationArea = All;
                Caption = 'Send';
                ToolTip = 'Send the email for processing in background. The status will change to Pending until it''s processed. If the email is successfully sent, it will no longer display in your Outbox.';
                Image = Email;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Enabled = not NoEmailsInOutbox and CanSendEmail;

                trigger OnAction()
                var
                    SelectedEmailOutbox: Record "Email Outbox";
                    EmailMessage: Codeunit "Email Message";
                    EmailRetryImpl: Codeunit "Email Retry Impl.";
                begin
                    CurrPage.SetSelectionFilter(SelectedEmailOutbox);
                    if not SelectedEmailOutbox.FindSet() then
                        exit;

                    repeat
                        if ((Rec.Status = Rec.Status::Failed) or (Rec.Status = Rec.Status::Draft)) and not TaskScheduler.TaskExists(Rec."Task Scheduler Id") then begin
                            EmailMessage.Get(SelectedEmailOutbox."Message Id");
                            EmailRetryImpl.CleanEmailRetryByMessageId(SelectedEmailOutbox."Message Id");
                            EmailImpl.Enqueue(EmailMessage, SelectedEmailOutbox."Account Id", SelectedEmailOutbox.Connector, CurrentDateTime());
                        end else
                            Error(EmailRetryNotCompletedMsg);
                    until SelectedEmailOutbox.Next() = 0;

                    LoadEmailOutboxForUser();
                    CurrPage.Update(false);
                end;
            }

            action(Refresh)
            {
                ApplicationArea = All;
                Caption = 'Refresh';
                ToolTip = 'Refresh';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;

                trigger OnAction()
                begin
                    LoadEmailOutboxForUser();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        LoadEmailOutboxForUser();
    end;

    trigger OnAfterGetRecord()
    begin
        // Updating the outbox for user is done via OnAfterGetRecord in the cases when an Email Message was changed from the Email Editor page.
        if RefreshOutbox then begin
            RefreshOutbox := false;
            LoadEmailOutboxForUser();
        end;

        FailedStatus := Rec.Status = Rec.Status::Failed;
        HasRetryDetail := EmailImpl.HasRetryDetail(Rec."Message Id");
        CanSendEmail := ((Rec.Status = Rec.Status::Failed) or (Rec.Status = Rec.Status::Draft)) and not TaskScheduler.TaskExists(Rec."Task Scheduler Id");
        NoEmailsInOutbox := false;
    end;

    trigger OnAfterGetCurrRecord()
    begin
        HasSourceRecord := EmailImpl.HasSourceRecord(Rec."Message Id");
    end;

    trigger OnDeleteRecord(): Boolean
    var
        EmailOutbox: Record "Email Outbox";
    begin
        if EmailOutbox.Get(Rec.Id) then
            EmailOutbox.Delete(true);

        HasSourceRecord := false;
        FailedStatus := false;
        NoEmailsInOutbox := true;
    end;

    local procedure LoadEmailOutboxForUser()
    begin
        EmailImpl.GetOutboxEmails(EmailAccountId, EmailStatus, Rec);

        Rec.SetCurrentKey("Date Queued");
        NoEmailsInOutbox := Rec.IsEmpty();
        Rec.Ascending(false);
        RecallThrottledEmailNotification();
        if ExistThrottledEmail(Rec) then
            ShowThrottledEmailInformation();
        EmailImpl.ShowAdminViewPolicyInEffectNotification();
    end;

    local procedure ExistThrottledEmail(EmailOutbox: Record "Email Outbox"): Boolean
    var
        RateLimitDuration: Duration;
        ActualDuration: Duration;
    begin
        RateLimitDuration := 1000 * 60; // one minute, rate limit is defined as emails per minute
        EmailOutbox.SetRange(Status, Enum::"Email Status"::Queued);
        if EmailOutbox.FindSet() then
            repeat
                if (EmailOutbox."Date Sending" <> 0DT) and (EmailOutbox."Date Queued" <> 0DT) then begin
                    ActualDuration := EmailOutbox."Date Sending" - EmailOutbox."Date Queued";
                    if ActualDuration >= RateLimitDuration then
                        exit(true)
                end;
            until EmailOutbox.Next() = 0;
        exit(false);
    end;

    local procedure RecallThrottledEmailNotification()
    var
        ThrottledEmailNotification: Notification;
    begin
        ThrottledEmailNotification.Id := EmailThrottledMsgIdTok;
        ThrottledEmailNotification.Recall();
    end;

    local procedure ShowThrottledEmailInformation()
    var
        ThrottledEmailNotification: Notification;
    begin
        ThrottledEmailNotification.Id := EmailThrottledMsgIdTok;
        ThrottledEmailNotification.Message(EmailThrottledMsg);
        ThrottledEmailNotification.Scope := NotificationScope::LocalScope;
        ThrottledEmailNotification.Send();
    end;

    local procedure ShowAccountInformation()
    var
        EmailAccountImpl: Codeunit "Email Account Impl.";
        EmailConnector: Interface "Email Connector";
    begin
        if not EmailAccountImpl.IsValidConnector(Rec.Connector) then
            Error(EmailConnectorHasBeenUninstalledMsg);

        EmailConnector := Rec.Connector;
        EmailConnector.ShowAccountInformation(Rec."Account Id");
    end;

    internal procedure SetEmailStatus(NewEmailStatus: Enum "Email Status")
    begin
        EmailStatus := NewEmailStatus;
    end;

    internal procedure SetEmailAccountId(AccountId: Guid)
    begin
        EmailAccountId := AccountId;
    end;

    var
        EmailImpl: Codeunit "Email Impl";
        EmailStatus: Enum "Email Status";
        EmailAccountId: Guid;
        RefreshOutbox: Boolean;
        CanSendEmail: Boolean;
        HasRetryDetail: Boolean;
        NoEmailsInOutbox: Boolean;
        FailedStatus: Boolean;
        HasSourceRecord: Boolean;
        EmailConnectorHasBeenUninstalledMsg: Label 'The email extension that was used to send this email has been uninstalled. To view information about the email account, you must reinstall the extension.';
        EmailRetryNotCompletedMsg: Label 'The selected email cannot be sent because it is still being retried. Please wait until the retry is complete.';
        EmailThrottledMsg: Label 'Your emails are being throttled due to the rate limit set on an account.';
        EmailThrottledMsgIdTok: Label '025cd7b4-9a12-44de-af35-d84f5e360438', Locked = true;
        CannotCancelRetryMsg: Label 'We cannot cancel the retry of this email because the background task has completed.';
        CancelSendSuccessMsg: Label 'The sending of the email has been cancelled.';
}
