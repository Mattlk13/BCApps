// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Email;

using System.Telemetry;
using System.Globalization;
using System.Security.AccessControl;
using System.Reflection;

codeunit 8900 "Email Impl"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;
    Permissions = tabledata "Sent Email" = rimd,
                  tabledata "Email Outbox" = rimd,
                  tabledata "Email Inbox" = rid,
                  tabledata "Email Related Record" = rid,
                  tabledata "Email Message" = r,
                  tabledata "Email Error" = r,
                  tabledata "Email Recipient" = r,
                  tabledata "Email View Policy" = r,
                  tabledata "Email Retry" = r;

    var
        EmailCategoryLbl: Label 'Email', Locked = true;
        EmailMessageDoesNotExistMsg: Label 'The email message has been deleted by another user.';
        EmailMessageCannotBeEditedErr: Label 'The email message has already been sent and cannot be edited.';
        EmailMessageQueuedErr: Label 'The email has already been queued.';
        EmailMessageSentErr: Label 'The email has already been sent.';
        InvalidEmailAccountErr: Label 'The provided email account does not exist.';
        InsufficientPermissionsErr: Label 'You do not have the permissions required to send emails. Ask your administrator to grant you the Read, Insert, Modify and Delete permissions for the Sent Email and Email Outbox tables.';
        SourceRecordErr: Label 'Could not find the source for this email.';
        EmailViewPolicyLbl: Label 'Email View Policy', Locked = true;
        EmailViewPolicyUsedTxt: Label 'Email View Policy is used', Locked = true;
        EmailViewPolicyDefaultTxt: Label 'Falling back to default email view policy: %1', Locked = true;
        EmailModifiedByEventTxt: Label 'Email has been modified by event', Locked = true;
        AdminViewPolicyInEffectNotificationIdTok: Label '0ee5d5db-5763-4acf-9808-10905a8997d5', Locked = true;
        AdminViewPolicyInEffectNotificationMsg: Label 'Your email view policy limits the emails visible. You can update your view policy to see all emails.';
        AdminViewPolicyUpdatePolicyNotificationActionLbl: Label 'Update policy';
        EmailConnectorDoesNotSupportRetrievingEmailsErr: Label 'The selected email connector does not support retrieving emails.';
        EmailConnectorDoesNotSupportMarkAsReadErr: Label 'The selected email connector does not support marking emails as read.';
        EmailconnectorDoesNotSupportReplyingErr: Label 'The selected email connector does not support replying to emails.';
        ExternalIdCannotBeEmptyErr: Label 'The external ID cannot be empty.';
        TelemetryRetrieveEmailsUsedTxt: Label 'Retrieving emails is used', Locked = true;
        ErrorCallStackNotFoundErr: Label 'Error call stack not found for the email message with ID %1.', Locked = true;
        EmailOutboxDoesNotExistErr: Label 'The email outbox does not exist for the email message with ID %1.', Locked = true;

    #region API

    procedure SaveAsDraft(EmailMessage: Codeunit "Email Message")
    var
        EmailOutbox: Record "Email Outbox";
    begin
        SaveAsDraft(EmailMessage, EmailOutbox);
    end;

    procedure SaveAsDraft(EmailMessage: Codeunit "Email Message"; var EmailOutbox: Record "Email Outbox")
    var
        EmailMessageImpl: Codeunit "Email Message Impl.";
        EmptyConnector: Enum "Email Connector";
        EmptyGuid: Guid;
    begin
        if not EmailMessageImpl.Get(EmailMessage.GetId()) then
            Error(EmailMessageDoesNotExistMsg);

        if GetEmailOutbox(EmailMessage.GetId(), EmailOutbox) and IsOutboxEnqueued(EmailOutbox) then
            exit;

        CreateOrUpdateEmailOutbox(EmailMessageImpl.GetId(), EmailMessageImpl.GetSubject(), EmptyGuid, EmptyConnector, Enum::"Email Status"::Draft, '', EmailOutbox);
    end;

    procedure SaveAsDraft(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"; var EmailOutbox: Record "Email Outbox")
    var
        EmailAccountRecord: Record "Email Account";
        EmailMessageImpl: Codeunit "Email Message Impl.";
    begin
        if not EmailMessageImpl.Get(EmailMessage.GetId()) then
            Error(EmailMessageDoesNotExistMsg);

        if GetEmailOutbox(EmailMessage.GetId(), EmailOutbox) and IsOutboxEnqueued(EmailOutbox) then
            exit;

        // Get email account
        GetEmailAccount(EmailAccountId, EmailConnector, EmailAccountRecord);
        CreateOrUpdateEmailOutbox(EmailMessageImpl.GetId(), EmailMessageImpl.GetSubject(), EmailAccountId, EmailConnector, Enum::"Email Status"::Draft, EmailAccountRecord."Email Address", EmailOutbox);
    end;

    procedure Enqueue(EmailMessage: Codeunit "Email Message"; EmailScenario: Enum "Email Scenario"; NotBefore: DateTime)
    var
        EmailAccount: Record "Email Account";
        EmailScenarios: Codeunit "Email Scenario";
    begin
        EmailScenarios.GetEmailAccount(EmailScenario, EmailAccount);

        Enqueue(EmailMessage, EmailAccount."Account Id", EmailAccount.Connector, NotBefore);
    end;

    procedure Enqueue(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"; NotBefore: DateTime)
    var
        EmailOutbox: Record "Email Outbox";
    begin
        Send(EmailMessage, EmailAccountId, EmailConnector, true, NotBefore, EmailOutbox);
    end;

    procedure Send(EmailMessage: Codeunit "Email Message"; EmailScenario: Enum "Email Scenario"): Boolean
    var
        EmailAccount: Record "Email Account";
        EmailScenarios: Codeunit "Email Scenario";
    begin
        EmailScenarios.GetEmailAccount(EmailScenario, EmailAccount);

        exit(Send(EmailMessage, EmailAccount."Account Id", EmailAccount.Connector));
    end;

    procedure Send(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"): Boolean
    var
        EmailOutbox: Record "Email Outbox";
    begin
        exit(Send(EmailMessage, EmailAccountId, EmailConnector, false, CurrentDateTime(), EmailOutbox));
    end;

    procedure Send(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"; var EmailOutbox: Record "Email Outbox"): Boolean
    begin
        exit(Send(EmailMessage, EmailAccountId, EmailConnector, false, CurrentDateTime(), EmailOutbox));
    end;

    procedure Reply(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"): Boolean
    var
        EmailOutbox: Record "Email Outbox";
    begin
        exit(Reply(EmailMessage, EmailAccountId, EmailConnector, EmailOutbox, CurrentDateTime(), false, false));
    end;

    procedure ReplyAll(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"): Boolean
    var
        EmailOutbox: Record "Email Outbox";
    begin
        exit(Reply(EmailMessage, EmailAccountId, EmailConnector, EmailOutbox, CurrentDateTime(), false, true));
    end;

    procedure Reply(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"; var EmailOutbox: Record "Email Outbox")
    begin
        Reply(EmailMessage, EmailAccountId, EmailConnector, EmailOutbox, CurrentDateTime(), true, false);
    end;

    procedure ReplyAll(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"; var EmailOutbox: Record "Email Outbox")
    begin
        Reply(EmailMessage, EmailAccountId, EmailConnector, EmailOutbox, CurrentDateTime(), true, true);
    end;

    procedure Reply(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"; var EmailOutbox: Record "Email Outbox"; NotBefore: DateTime; InBackground: Boolean; ReplyToAll: Boolean): Boolean
    var
        EmailAccountRec: Record "Email Account";
        CurrentUser: Record User;
        Email: Codeunit Email;
        EmailDispatcher: Codeunit "Email Dispatcher";
        EmailMessageImpl: Codeunit "Email Message Impl.";
        TaskId: Guid;
    begin
        CheckRequiredPermissions();

        if not EmailMessageImpl.Get(EmailMessage.GetId()) then
            Error(EmailMessageDoesNotExistMsg);

        if EmailMessageSent(EmailMessage.GetId()) then
            Error(EmailMessageSentErr);

        if not ReplyToAll then
            EmailMessageImpl.ValidateRecipients();

        if GetEmailOutbox(EmailMessage.GetId(), EmailOutbox) and IsOutboxEnqueued(EmailOutbox) then
            Error(EmailMessageQueuedErr);

        if EmailMessage.GetExternalId() = '' then
            Error(ExternalIdCannotBeEmptyErr);

        // Get email account
        GetEmailAccount(EmailAccountId, EmailConnector, EmailAccountRec);

        CheckReplySupported(EmailConnector);

        // Add user as an related entity on email
        if CurrentUser.Get(UserSecurityId()) then
            Email.AddRelation(EmailMessage, Database::User, CurrentUser.SystemId, Enum::"Email Relation Type"::"Related Entity", Enum::"Email Relation Origin"::"Compose Context");

        BeforeReplyEmail(EmailMessage);
        CreateOrUpdateEmailOutbox(EmailMessage.GetId(), EmailMessage.GetSubject(), EmailAccountId, EmailConnector, Enum::"Email Status"::Queued, EmailAccountRec."Email Address", EmailOutbox);
        Email.OnEnqueuedReplyInOutbox(EmailMessage.GetId());

        if InBackground then begin
            TaskId := TaskScheduler.CreateTask(Codeunit::"Email Dispatcher", Codeunit::"Email Error Handler", true, CompanyName(), NotBefore, EmailOutbox.RecordId());
            EmailOutbox."Task Scheduler Id" := TaskId;
            EmailOutbox."Date Sending" := NotBefore;
            EmailOutbox."Is Background Task" := true;
            EmailOutbox.Modify();
        end else begin // Send the email in foreground
            Commit();
            if EmailDispatcher.Run(EmailOutbox) then;
            exit(EmailDispatcher.GetSuccess());
        end;
    end;

    procedure RetrieveEmails(EmailAccountId: Guid; Connector: Enum "Email Connector"; var EmailInbox: Record "Email Inbox")
    var
        Filters: Record "Email Retrieval Filters";
    begin
        Filters.Insert();
        RetrieveEmails(EmailAccountId, Connector, EmailInbox, Filters);
    end;

    procedure RetrieveEmails(EmailAccountId: Guid; Connector: Enum "Email Connector"; var EmailInbox: Record "Email Inbox"; var Filters: Record "Email Retrieval Filters" temporary)
    var
#if not CLEAN26
#pragma warning disable AL0432
        EmailConnectorv2: Interface "Email Connector v2";
#pragma warning restore AL0432
#endif
        EmailConnectorv3: Interface "Email Connector v3";
    begin
        CheckRequiredPermissions();

        if CheckAndGetEmailConnectorv3(Connector, EmailConnectorv3) then begin
            TelemetryAppsAndPublishers(TelemetryRetrieveEmailsUsedTxt);
            EmailConnectorv3.RetrieveEmails(EmailAccountId, EmailInbox, Filters);
            EmailInbox.MarkedOnly(true);
            exit;
        end;
#if not CLEAN26
#pragma warning disable AL0432
        if CheckAndGetEmailConnectorv2(Connector, EmailConnectorv2) then begin
#pragma warning restore AL0432
            TelemetryAppsAndPublishers(TelemetryRetrieveEmailsUsedTxt);
            EmailConnectorv2.RetrieveEmails(EmailAccountId, EmailInbox);
            EmailInbox.MarkedOnly(true);
            exit;
        end;
#endif

        Error(EmailConnectorDoesNotSupportRetrievingEmailsErr);
    end;

    local procedure TelemetryAppsAndPublishers(Message: Text)
    var
        Telemetry: Codeunit Telemetry;
        CallerCallStackModuleInfos: List of [ModuleInfo];
        CallerModuleInfo: ModuleInfo;
        CustomDimensions: Dictionary of [Text, Text];
        AppsAndPublishersDict: Dictionary of [Text, Boolean];
        AppsAndPublishers: Text;
    begin
        CallerCallStackModuleInfos := NavApp.GetCallerCallstackModuleInfos();

        foreach CallerModuleInfo in CallerCallStackModuleInfos do
            if not AppsAndPublishersDict.ContainsKey(CallerModuleInfo.Id) then begin
                AppsAndPublishersDict.Add(CallerModuleInfo.Id, true);
                AppsAndPublishers := StrSubstNo('%1, %2 - (%3 - %4)', AppsAndPublishers, CallerModuleInfo.Id, CallerModuleInfo.Name, CallerModuleInfo.Publisher);
            end;

        CustomDimensions.Add('AppsAndPublishers', AppsAndPublishers);
        CustomDimensions.Add('Category', EmailCategoryLbl);
        Telemetry.LogMessage('0000NIG', Message, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All, CustomDimensions);
    end;

    procedure MarkAsRead(EmailAccountId: Guid; Connector: Enum "Email Connector"; ExternalId: Text)
    var
#if not CLEAN26
#pragma warning disable AL0432
        EmailConnectorv2: Interface "Email Connector v2";
#pragma warning restore AL0432
#endif
        EmailConnectorv3: Interface "Email Connector v3";
    begin
        CheckRequiredPermissions();

        if ExternalId = '' then
            Error(ExternalIdCannotBeEmptyErr);

        if CheckAndGetEmailConnectorv3(Connector, EmailConnectorv3) then begin
            EmailConnectorv3.MarkAsRead(EmailAccountId, ExternalId);
            exit;
        end;
#if not CLEAN26
#pragma warning disable AL0432
        if CheckAndGetEmailConnectorv2(Connector, EmailConnectorv2) then begin
#pragma warning restore AL0432
            EmailConnectorv2.MarkAsRead(EmailAccountId, ExternalId);
            exit;
        end;
#endif

        Error(EmailConnectorDoesNotSupportMarkAsReadErr);
    end;

    procedure CheckReplySupported(Connector: Enum "Email Connector"): Boolean
    var
#if not CLEAN26
#pragma warning disable AL0432
        EmailConnectorv2: Interface "Email Connector v2";
#pragma warning restore AL0432
#endif
        EmailConnectorv3: Interface "Email Connector v3";
    begin
        if CheckAndGetEmailConnectorv3(Connector, EmailConnectorv3) then
            exit(true);
#if not CLEAN26
#pragma warning disable AL0432
        if CheckAndGetEmailConnectorv2(Connector, EmailConnectorv2) then
            exit(true);
#pragma warning restore AL0432
#endif

        Error(EmailconnectorDoesNotSupportReplyingErr);
    end;
#if not CLEAN26
#pragma warning disable AL0432
    [Obsolete('Replaced by CheckAndGetEmailConnectorv3.', '26.0')]
    procedure CheckAndGetEmailConnectorv2(Connector: Interface "Email Connector"; var Connectorv2: Interface "Email Connector v2"): Boolean
#pragma warning restore AL0432
    begin
        if Connector is "Email Connector v2" then begin
            Connectorv2 := Connector as "Email Connector v2";
            exit(true);
        end else
            exit(false);
    end;
#endif

    procedure CheckAndGetEmailConnectorv3(Connector: Interface "Email Connector"; var Connectorv3: Interface "Email Connector v3"): Boolean
    begin
        if Connector is "Email Connector v3" then begin
            Connectorv3 := Connector as "Email Connector v3";
            exit(true);
        end else
            exit(false);
    end;

    procedure OpenInEditor(EmailMessage: Codeunit "Email Message"; EmailScenario: Enum "Email Scenario"; IsModal: Boolean): Enum "Email Action"
    var
        EmailAccount: Record "Email Account";
        EmailScenarios: Codeunit "Email Scenario";
    begin
        EmailScenarios.GetEmailAccount(EmailScenario, EmailAccount);

        exit(OpenInEditor(EmailMessage, EmailAccount."Account Id", EmailAccount.Connector, IsModal));
    end;

    procedure OpenInEditor(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"; IsModal: Boolean): Enum "Email Action"
    var
        EmailOutbox: Record "Email Outbox";
        EmailMessageImpl: Codeunit "Email Message Impl.";
        EmailEditor: Codeunit "Email Editor";
        IsNew, IsEnqueued : Boolean;
    begin
        if not EmailMessageImpl.Get(EmailMessage.GetId()) then
            Error(EmailMessageDoesNotExistMsg);

        if EmailMessageImpl.IsRead() then
            Error(EmailMessageCannotBeEditedErr);

        IsNew := not GetEmailOutbox(EmailMessageImpl.GetId(), EmailOutbox);
        IsEnqueued := (not IsNew) and IsOutboxEnqueued(EmailOutbox);

        if not IsEnqueued then begin
            // Modify the outbox only if it hasn't been enqueued yet
            CreateOrUpdateEmailOutbox(EmailMessageImpl.GetId(), EmailMessageImpl.GetSubject(), EmailAccountId, EmailConnector, Enum::"Email Status"::Draft, '', EmailOutbox);

            // Set the record as new so that there is a save prompt and no arrows
            EmailEditor.SetAsNew();
        end;

        exit(EmailEditor.Open(EmailOutbox, IsModal));
    end;

    procedure OpenInEditorWithScenario(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"; IsModal: Boolean; Scenario: Enum "Email Scenario"): Enum "Email Action"
    var
        EmailOutbox: Record "Email Outbox";
        EmailMessageImpl: Codeunit "Email Message Impl.";
        EmailScenarioAttachmentsImpl: Codeunit "Email Scenario Attach Impl.";
        EmailEditor: Codeunit "Email Editor";
        IsNew, IsEnqueued : Boolean;
    begin
        if not EmailMessageImpl.Get(EmailMessage.GetId()) then
            Error(EmailMessageDoesNotExistMsg);

        if EmailMessageImpl.IsRead() then
            Error(EmailMessageCannotBeEditedErr);

        IsNew := not GetEmailOutbox(EmailMessageImpl.GetId(), EmailOutbox);
        IsEnqueued := (not IsNew) and IsOutboxEnqueued(EmailOutbox);

        if not IsEnqueued then begin
            // Modify the outbox only if it hasn't been enqueued yet
            CreateOrUpdateEmailOutbox(EmailMessageImpl.GetId(), EmailMessageImpl.GetSubject(), EmailAccountId, EmailConnector, Enum::"Email Status"::Draft, '', EmailOutbox);

            // Set the record as new so that there is a save prompt and no arrows
            EmailEditor.SetAsNew();
        end;

        EmailScenarioAttachmentsImpl.AddAttachmentToMessage(EmailMessage, Scenario);

        exit(EmailEditor.OpenWithScenario(EmailOutbox, IsModal, Scenario));
    end;

    local procedure GetEmailOutbox(EmailMessageId: Guid; var EmailOutbox: Record "Email Outbox"): Boolean
    begin
        EmailOutbox.SetRange("Message Id", EmailMessageId);
        exit(EmailOutbox.FindFirst());
    end;

    local procedure IsOutboxEnqueued(EmailOutbox: Record "Email Outbox"): Boolean
    begin
        exit((EmailOutbox.Status in [Enum::"Email Status"::Queued, Enum::"Email Status"::Processing]));
    end;

    local procedure EmailMessageSent(EmailMessageId: Guid): Boolean
    var
        SentEmail: Record "Sent Email";
    begin
        SentEmail.SetRange("Message Id", EmailMessageId);
        exit(not SentEmail.IsEmpty());
    end;

    procedure AddDefaultAttachments(EmailMessage: Codeunit "Email Message"; EmailScenario: Enum "Email Scenario")
    var
        EmailScenarioAttachmentsImpl: Codeunit "Email Scenario Attach Impl.";
    begin
        EmailScenarioAttachmentsImpl.AddAttachmentToMessage(EmailMessage, EmailScenario);
    end;

    local procedure Send(EmailMessage: Codeunit "Email Message"; EmailAccountId: Guid; EmailConnector: Enum "Email Connector"; InBackground: Boolean; NotBefore: DateTime; var EmailOutbox: Record "Email Outbox"): Boolean
    var
        EmailAccountRec: Record "Email Account";
        CurrentUser: Record User;
        Email: Codeunit Email;
        EmailMessageImpl: Codeunit "Email Message Impl.";
        EmailDispatcher: Codeunit "Email Dispatcher";
        TaskId: Guid;
    begin
        CheckRequiredPermissions();

        if not EmailMessageImpl.Get(EmailMessage.GetId()) then
            Error(EmailMessageDoesNotExistMsg);

        if EmailMessageSent(EmailMessage.GetId()) then
            Error(EmailMessageSentErr);

        EmailMessageImpl.ValidateRecipients();

        if GetEmailOutbox(EmailMessage.GetId(), EmailOutbox) and IsOutboxEnqueued(EmailOutbox) then
            Error(EmailMessageQueuedErr);

        // Get email account
        GetEmailAccount(EmailAccountId, EmailConnector, EmailAccountRec);

        // Add user as an related entity on email
        if CurrentUser.Get(UserSecurityId()) then
            Email.AddRelation(EmailMessage, Database::User, CurrentUser.SystemId, Enum::"Email Relation Type"::"Related Entity", Enum::"Email Relation Origin"::"Compose Context");

        BeforeSendEmail(EmailMessage);
        CreateOrUpdateEmailOutbox(EmailMessageImpl.GetId(), EmailMessageImpl.GetSubject(), EmailAccountId, EmailConnector, Enum::"Email Status"::Queued, EmailAccountRec."Email Address", EmailOutbox);
        Email.OnEnqueuedInOutbox(EmailMessage.GetId());

        if InBackground then begin
            TaskId := TaskScheduler.CreateTask(Codeunit::"Email Dispatcher", Codeunit::"Email Error Handler", true, CompanyName(), NotBefore, EmailOutbox.RecordId());
            EmailOutbox."Task Scheduler Id" := TaskId;
            EmailOutbox."Date Sending" := NotBefore;
            EmailOutbox."Is Background Task" := true;
            EmailOutbox.Modify();
        end else begin // Send the email in foreground
            Commit();

            if EmailDispatcher.Run(EmailOutbox) then;
            exit(EmailDispatcher.GetSuccess());
        end;
    end;

    local procedure BeforeSendEmail(var EmailMessage: Codeunit "Email Message")
    var
        Email: Codeunit Email;
        Telemetry: Codeunit Telemetry;
        Dimensions: Dictionary of [Text, Text];
        LastModifiedNo: Integer;
        EmailMessageId: Guid;
    begin
        EmailMessageId := EmailMessage.GetId(); // Prevent different email message from being sent if overwritten in event
        LastModifiedNo := EmailMessage.GetNoOfModifies();

        Email.OnBeforeSendEmail(EmailMessage);

        EmailMessage.Get(EmailMessageId); // Get any latest changes
        if LastModifiedNo < EmailMessage.GetNoOfModifies() then begin
            Dimensions.Add('Category', EmailCategoryLbl);
            Dimensions.Add('EmailMessageId', EmailMessage.GetId());
            Telemetry.LogMessage('0000I2F', EmailModifiedByEventTxt, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All, Dimensions);
        end;
    end;

    local procedure BeforeReplyEmail(var EmailMessage: Codeunit "Email Message")
    var
        Email: Codeunit Email;
        Telemetry: Codeunit Telemetry;
        Dimensions: Dictionary of [Text, Text];
        LastModifiedNo: Integer;
        EmailMessageId: Guid;
    begin
        EmailMessageId := EmailMessage.GetId(); // Prevent different email message from being sent if overwritten in event
        LastModifiedNo := EmailMessage.GetNoOfModifies();

        Email.OnBeforeReplyEmail(EmailMessage);

        EmailMessage.Get(EmailMessageId); // Get any latest changes
        if LastModifiedNo < EmailMessage.GetNoOfModifies() then begin
            Dimensions.Add('Category', EmailCategoryLbl);
            Dimensions.Add('EmailMessageId', EmailMessage.GetId());
            Telemetry.LogMessage('0000NIH', EmailModifiedByEventTxt, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All, Dimensions);
        end;
    end;

    local procedure GetEmailAccount(EmailAccountIdGuid: Guid; EmailConnectorEnum: Enum "Email Connector"; var EmailAccountRecord: Record "Email Account")
    var
        EmailAccount: Codeunit "Email Account";
    begin
        EmailAccount.GetAllAccounts(false, EmailAccountRecord);
        if not EmailAccountRecord.Get(EmailAccountIdGuid, EmailConnectorEnum) then
            Error(InvalidEmailAccountErr);
    end;

    local procedure CreateOrUpdateEmailOutbox(EmailMessageId: Guid; Subject: Text; AccountId: Guid; EmailConnector: Enum "Email Connector"; Status: Enum "Email Status"; SentFrom: Text; var EmailOutbox: Record "Email Outbox")
    begin
        if not GetEmailOutbox(EmailMessageId, EmailOutbox) then begin
            EmailOutbox."Message Id" := EmailMessageId;
            EmailOutbox.Insert();
        end;

        EmailOutbox.Connector := EmailConnector;
        EmailOutbox."Account Id" := AccountId;
        EmailOutbox.Description := CopyStr(Subject, 1, MaxStrLen(EmailOutbox.Description));
        EmailOutbox."User Security Id" := UserSecurityId();
        EmailOutbox."Send From" := CopyStr(SentFrom, 1, MaxStrLen(EmailOutbox."Send From"));
        EmailOutbox.Status := Status;
        if Status = Enum::"Email Status"::Queued then begin
            EmailOutbox."Date Queued" := CurrentDateTime();
            EmailOutbox."Date Sending" := CurrentDateTime();
        end;
        EmailOutbox.Modify();
    end;

    #endregion

    procedure FindLastErrorCallStack(EmailOutboxId: BigInteger): Text
    var
        EmailError: Record "Email Error";
        ErrorInstream: InStream;
        ErrorText: Text;
    begin
        EmailError.SetRange("Outbox Id", EmailOutboxId);
        EmailError.FindLast();
        EmailError.CalcFields(EmailError."Error Callstack");
        EmailError."Error Callstack".CreateInStream(ErrorInstream, TextEncoding::UTF8);
        ErrorInstream.ReadText(ErrorText);
        exit(ErrorText);
    end;

    procedure FindErrorCallStackWithMsgIDAndRetryNo(MessageId: Guid; RetryNo: Integer): Text
    var
        EmailError: Record "Email Error";
        EmailOutbox: Record "Email Outbox";
        ErrorInstream: InStream;
        ErrorText: Text;
    begin
        EmailOutbox.SetRange("Message Id", MessageId);
        if not EmailOutbox.FindFirst() then
            Error(EmailOutboxDoesNotExistErr, MessageId);

        EmailError.SetRange("Outbox Id", EmailOutbox.Id);
        EmailError.SetRange("Retry No.", RetryNo);
        if not EmailError.FindFirst() then
            Error(ErrorCallStackNotFoundErr, MessageId);
        EmailError.CalcFields(EmailError."Error Callstack");
        EmailError."Error Callstack".CreateInStream(ErrorInstream, TextEncoding::UTF8);
        ErrorInstream.ReadText(ErrorText);
        exit(ErrorText);
    end;

    procedure ShowSourceRecord(EmailMessageId: Guid);
    var
        EmailRelatedRecord: Record "Email Related Record";
        Email: Codeunit Email;
        EmailRelationPicker: Page "Email Relation Picker";
        IsHandled: Boolean;
    begin
        EmailRelatedRecord.SetRange("Email Message Id", EmailMessageId);

        if not EmailRelatedRecord.FindFirst() then
            Error(SourceRecordErr);

        if EmailRelatedRecord.Count() > 1 then begin
            FilterRemovedSourceRecords(EmailRelatedRecord);
            EmailRelationPicker.SetTableView(EmailRelatedRecord);
            EmailRelationPicker.LookupMode(true);
            if EmailRelationPicker.RunModal() <> Action::LookupOK then
                exit;
            EmailRelationPicker.GetRecord(EmailRelatedRecord);
        end;

        Email.OnShowSource(EmailRelatedRecord."Table Id", EmailRelatedRecord."System Id", IsHandled);

        if not IsHandled then
            Error(SourceRecordErr);
    end;

    procedure HasRetryDetail(EmailMessageId: Guid): Boolean
    var
        EmailRetryDetail: Record "Email Retry";
    begin
        EmailRetryDetail.SetRange("Message Id", EmailMessageId);
        exit(not EmailRetryDetail.IsEmpty());
    end;

    procedure HasSourceRecord(EmailMessageId: Guid): Boolean;
    var
        EmailRelatedRecord: Record "Email Related Record";
    begin
        EmailRelatedRecord.SetRange("Email Message Id", EmailMessageId);
        exit(not EmailRelatedRecord.IsEmpty());
    end;

    procedure FilterRemovedSourceRecords(var EmailRelatedRecord: Record "Email Related Record")
    var
        AllObj: Record AllObj;
        SourceRecordRef: RecordRef;
    begin
        repeat
            if AllObj.Get(AllObj."Object Type"::Table, EmailRelatedRecord."Table Id") then begin
                SourceRecordRef.Open(EmailRelatedRecord."Table Id");
                if SourceRecordRef.ReadPermission() then
                    if SourceRecordRef.GetBySystemId(EmailRelatedRecord."System Id") then
                        EmailRelatedRecord.Mark(true);
                SourceRecordRef.Close();
            end;
        until EmailRelatedRecord.Next() = 0;
        EmailRelatedRecord.MarkedOnly(true);
    end;

    procedure GetSentEmailsForRecord(RecordVariant: Variant; var ResultSentEmails: Record "Sent Email" temporary)
    var
        RecordRef: RecordRef;
    begin
        if GetRecordRef(RecordVariant, RecordRef) then
            GetSentEmailsForRecord(RecordRef.Number, RecordRef.Field(RecordRef.SystemIdNo).Value, ResultSentEmails);
    end;

    procedure GetSentEmailsForRecord(TableId: Integer; SystemId: Guid; var ResultSentEmails: Record "Sent Email" temporary)
    var
        NullGuid: Guid;
    begin
        GetSentEmails(NullGuid, 0DT, TableId, SystemId, ResultSentEmails);
    end;

    procedure GetSentEmails(AccountId: Guid; NewerThan: DateTime; var SentEmails: Record "Sent Email" temporary)
    var
        NullGuid: Guid;
    begin
        GetSentEmails(AccountId, NewerThan, 0, NullGuid, SentEmails);
    end;

    procedure GetSentEmails(AccountId: Guid; NewerThan: DateTime; SourceTableID: Integer; SourceSystemID: Guid; var SentEmails: Record "Sent Email" temporary)
    var
        EmailViewPolicy: Interface "Email View Policy";
    begin
        if not SentEmails.IsEmpty() then
            SentEmails.DeleteAll();

        if not IsNullGuid(AccountId) then
            SentEmails.SetRange("Account Id", AccountId);

        if NewerThan <> 0DT then
            SentEmails.SetRange("Date Time Sent", NewerThan, System.CurrentDateTime());

        EmailViewPolicy := GetUserEmailViewPolicy();

        if SourceTableID <> 0 then
            if IsNullGuid(SourceSystemID) then
                EmailViewPolicy.GetSentEmails(SourceTableID, SentEmails)
            else
                EmailViewPolicy.GetSentEmails(SourceTableID, SourceSystemID, SentEmails)
        else
            EmailViewPolicy.GetSentEmails(SentEmails);
    end;

    procedure RefreshEmailOutboxForUser(EmailAccountId: Guid; EmailStatus: Enum "Email Status"; var EmailOutboxForUser: Record "Email Outbox" temporary)
    begin
        GetOutboxEmails(EmailAccountId, EmailStatus, EmailOutboxForUser);
    end;

    procedure GetOutboxEmails(AccountId: Guid; EmailStatus: Enum "Email Status"; var EmailOutboxForUser: Record "Email Outbox" temporary)
    var
        NullGuid: Guid;
    begin
        GetOutboxEmails(AccountId, EmailStatus, 0, NullGuid, EmailOutboxForUser);
    end;

    procedure GetOutboxEmails(AccountId: Guid; EmailStatus: Enum "Email Status"; SourceTableID: Integer; SourceSystemID: Guid; var EmailOutboxForUser: Record "Email Outbox" temporary)
    var
        EmailViewPolicy: Interface "Email View Policy";
    begin
        if not EmailOutboxForUser.IsEmpty() then
            EmailOutboxForUser.DeleteAll();

        if not IsNullGuid(AccountId) then
            EmailOutboxForUser.SetRange("Account Id", AccountId);

        if EmailStatus.AsInteger() <> 0 then
            EmailOutboxForUser.SetRange(Status, EmailStatus);

        EmailViewPolicy := GetUserEmailViewPolicy();

        if SourceTableID <> 0 then
            if IsNullGuid(SourceSystemID) then
                EmailViewPolicy.GetOutboxEmails(SourceTableID, EmailOutboxForUser)
            else
                EmailViewPolicy.GetOutboxEmails(SourceTableID, SourceSystemID, EmailOutboxForUser)
        else
            EmailViewPolicy.GetOutboxEmails(EmailOutboxForUser);
    end;

    procedure GetEmailOutboxForRecord(RecordVariant: Variant; var ResultEmailOutbox: Record "Email Outbox" temporary)
    var
        RecordRef: RecordRef;
    begin
        if GetRecordRef(RecordVariant, RecordRef) then
            GetEmailOutboxForRecord(RecordRef.Number, RecordRef.Field(RecordRef.SystemIdNo).Value, ResultEmailOutbox);
    end;

    procedure GetEmailOutboxForRecord(TableId: Integer; SystemId: Guid; var ResultEmailOutbox: Record "Email Outbox" temporary)
    var
        NullGuid: Guid;
    begin
        GetOutboxEmails(NullGuid, Enum::"Email Status"::" ", TableId, SystemId, ResultEmailOutbox);
    end;

    procedure GetOutboxEmailRecordStatus(MessageId: Guid) ResultStatus: Enum "Email Status"
    var
        TempEmailOutboxRecord: Record "Email Outbox" temporary;
        NullGuid: Guid;
    begin
        GetOutboxEmails(NullGuid, Enum::"Email Status"::" ", TempEmailOutboxRecord);
        TempEmailOutboxRecord.SetRange("Message Id", MessageId);
        TempEmailOutboxRecord.FindFirst();
        exit(TempEmailOutboxRecord.Status);
    end;

    internal procedure GetUserEmailViewPolicy() Result: Enum "Email View Policy"
    var
        EmailViewPolicy: Record "Email View Policy";
        Telemetry: Codeunit Telemetry;
        NullGuid: Guid;
    begin
        //Try get the user's view policy
        if EmailViewPolicy.Get(UserSecurityId()) then begin
            EmitUsedTelemetry(EmailViewPolicy);
            exit(EmailViewPolicy."Email View Policy");
        end;

        // Try get the default view policy
        if EmailViewPolicy.Get(NullGuid) then
            exit(EmailViewPolicy."Email View Policy");

        // Fallback to "All Related Records Emails" if email view policy has not been configured
        Result := Enum::"Email View Policy"::AllRelatedRecordsEmails;

        Telemetry.LogMessage('0000GPE', StrSubstNo(EmailViewPolicyDefaultTxt, Result.AsInteger()), Verbosity::Normal, DataClassification::SystemMetadata);
        exit(Result);
    end;

    internal procedure CountEmailsInOutbox(EmailStatus: Enum "Email Status"; IsAdmin: Boolean): Integer
    var
        TempEmailOutboxRecord: Record "Email Outbox" temporary;
        NullGuid: Guid;
    begin
        GetOutboxEmails(NullGuid, EmailStatus, TempEmailOutboxRecord);
        exit(TempEmailOutboxRecord.Count());
    end;

    internal procedure CountSentEmails(NewerThan: DateTime; IsAdmin: Boolean): Integer
    var
        TempSentEmailsRecord: Record "Sent Email" temporary;
        NullGuid: Guid;
    begin
        GetSentEmails(NullGuid, NewerThan, TempSentEmailsRecord);
        exit(TempSentEmailsRecord.Count());
    end;

    procedure AddRelation(EmailMessage: Codeunit "Email Message"; TableId: Integer; SystemId: Guid; RelationType: Enum "Email Relation Type"; Origin: Enum "Email Relation Origin")
    var
        Email: Codeunit Email;
        RelatedRecord: Dictionary of [Integer, List of [Guid]];
        RelatedRecordTableIds: List of [Integer];
        RelatedRecordSystemIds: List of [Guid];
        RelatedRecordTableId: Integer;
        TableIdCount, SystemIdCount : Integer;
    begin
        AddRelation(EmailMessage.GetId(), TableId, SystemId, RelationType, Origin);
        Email.OnAfterAddRelation(EmailMessage.GetId(), TableId, SystemId, RelatedRecord);

        RelatedRecordTableIds := RelatedRecord.Keys();
        for TableIdCount := 1 to RelatedRecordTableIds.Count() do begin
            RelatedRecordTableId := RelatedRecordTableIds.Get(TableIdCount);
            RelatedRecordSystemIds := RelatedRecord.Get(RelatedRecordTableId);
            for SystemIdCount := 1 to RelatedRecordSystemIds.Count() do
                AddRelation(EmailMessage.GetId(), RelatedRecordTableId, RelatedRecordSystemIds.Get(SystemIdCount), Enum::"Email Relation Type"::"Related Entity", Origin);
        end;
    end;

    procedure AddRelation(EmailMessageId: Guid; TableId: Integer; SystemId: Guid; RelationType: Enum "Email Relation Type"; Origin: Enum "Email Relation Origin")
    var
        EmailRelatedRecord: Record "Email Related Record";
    begin
        if EmailRelatedRecord.Get(TableId, SystemId, EmailMessageId) then
            exit;

        EmailRelatedRecord."Email Message Id" := EmailMessageId;
        EmailRelatedRecord."Table Id" := TableId;
        EmailRelatedRecord."System Id" := SystemId;
        EmailRelatedRecord."Relation Type" := RelationType;
        EmailRelatedRecord."Relation Origin" := Origin;
        EmailRelatedRecord.Insert();
    end;

    procedure RemoveRelation(EmailMessage: Codeunit "Email Message"; TableId: Integer; SystemId: Guid): Boolean
    var
        EmailRelatedRecord: Record "Email Related Record";
        Email: Codeunit Email;
    begin
        if EmailRelatedRecord.Get(TableId, SystemId, EmailMessage.GetId()) then
            if EmailRelatedRecord.Delete() then begin
                Email.OnAfterRemoveRelation(EmailMessage.GetId(), TableId, SystemId);
                exit(true);
            end;
        exit(false);
    end;

    procedure OpenSentEmails(RecordVariant: Variant)
    var
        RecordRef: RecordRef;
    begin
        if GetRecordRef(RecordVariant, RecordRef) then
            OpenSentEmails(RecordRef.Number, RecordRef.Field(RecordRef.SystemIdNo).Value);
    end;

    procedure OpenSentEmails(TableId: Integer; SystemId: Guid)
    var
        SentEmails: Page "Sent Emails";
    begin
        SentEmails.SetRelatedRecord(TableId, SystemId);
        SentEmails.Run();
    end;

    procedure OpenSentEmails(TableId: Integer; SystemId: Guid; NewerThanDate: DateTime)
    var
        SentEmails: Page "Sent Emails";
    begin
        SentEmails.SetRelatedRecord(TableId, SystemId);
        SentEmails.SetNewerThan(NewerThanDate);
        SentEmails.Run();
    end;

    procedure GetEmailOutboxSentEmailWithinRateLimit(var SentEmail: Record "Sent Email"; var EmailOutbox: Record "Email Outbox"; AccountId: Guid): Duration
    var
        EmailCheckWindowTime: DateTime;
        EmailOutboxWindowTime: DateTime;
        RateLimitDuration: Duration;
        OneHourDuration: Duration;
    begin
        RateLimitDuration := 1000 * 60; // one minute, rate limit is defined as emails per minute
        EmailCheckWindowTime := CurrentDateTime() - RateLimitDuration;
        SentEmail.SetRange("Account Id", AccountId);
        SentEmail.SetFilter("Date Time Sent", '>%1', EmailCheckWindowTime);
        EmailOutbox.SetRange("Account Id", AccountId);
        EmailOutbox.SetRange(Status, Enum::"Email Status"::Processing);
        OneHourDuration := 1000 * 60 * 60; // one hour
        EmailOutboxWindowTime := CurrentDateTime() - OneHourDuration;
        EmailOutbox.SetFilter(SystemModifiedAt, '>%1', EmailOutboxWindowTime); // If the email was last processed more than an hour ago, then it's stuck in processing and we should not base rate limit on it
        exit(RateLimitDuration);
    end;

    internal procedure GetRecordRef(RecRelatedVariant: Variant; var ResultRecordRef: RecordRef): Boolean
    var
        RecID: RecordId;
    begin
        case true of
            RecRelatedVariant.IsRecord:
                ResultRecordRef.GetTable(RecRelatedVariant);
            RecRelatedVariant.IsRecordRef:
                ResultRecordRef := RecRelatedVariant;
            RecRelatedVariant.IsRecordId:
                begin
                    RecID := RecRelatedVariant;
                    if RecID.TableNo = 0 then
                        exit(false);
                    if not ResultRecordRef.Get(RecID) then
                        ResultRecordRef.Open(RecID.TableNo);
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure CheckRequiredPermissions()
    var
        [SecurityFiltering(SecurityFilter::Ignored)]
        SentEmail: Record "Sent Email";
        [SecurityFiltering(SecurityFilter::Ignored)]
        EmailOutBox: Record "Email Outbox";
    begin
        if not SentEmail.ReadPermission() or
                not SentEmail.WritePermission() or
                not EmailOutBox.ReadPermission() or
                not EmailOutBox.WritePermission() then
            Error(InsufficientPermissionsErr);
    end;

    procedure ShowAdminViewPolicyInEffectNotification()
    var
        EmailAccountImpl: Codeunit "Email Account Impl.";
        AdminViewPolicyInEffectNotification: Notification;
    begin
        if not EmailAccountImpl.IsUserEmailAdmin() then
            exit;

        if GetUserEmailViewPolicy() = Enum::"Email View Policy"::AllEmails then
            exit;

        AdminViewPolicyInEffectNotification.Id := AdminViewPolicyInEffectNotificationIdTok;
        AdminViewPolicyInEffectNotification.Message(AdminViewPolicyInEffectNotificationMsg);
        AdminViewPolicyInEffectNotification.Scope := NotificationScope::LocalScope;
        AdminViewPolicyInEffectNotification.AddAction(AdminViewPolicyUpdatePolicyNotificationActionLbl, Codeunit::"Email Impl", 'OpenEmailViewPoliciesPage');
        AdminViewPolicyInEffectNotification.Send();
    end;

    procedure OpenEmailViewPoliciesPage(AdminViewPolicyInEffectNotification: Notification)
    begin
        Page.Run(Page::"Email View Policy List");
    end;

    #region Telemetry
    local procedure EmitUsedTelemetry(EmailViewPolicy: Record "Email View Policy")
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUptake('0000GO9', EmailViewPolicyLbl, Enum::"Feature Uptake Status"::Used, GetTelemetryDimensions(EmailViewPolicy));

        FeatureTelemetry.LogUsage('0000GPD', EmailViewPolicyLbl, EmailViewPolicyUsedTxt, GetTelemetryDimensions(EmailViewPolicy));
    end;

    [EventSubscriber(ObjectType::Table, Database::"Email View Policy", OnAfterInsertEvent, '', false, false)]
    local procedure EmitSetupTelemetry(var Rec: Record "Email View Policy")
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        if not IsNullGuid(Rec."User Security ID") then
            FeatureTelemetry.LogUptake('0000GOB', EmailViewPolicyLbl, Enum::"Feature Uptake Status"::"Set up", GetTelemetryDimensions(Rec));
    end;

    local procedure GetTelemetryDimensions(EmailViewPolicy: Record "Email View Policy") TelemetryDimensions: Dictionary of [Text, Text]
    var
        Language: Codeunit Language;
        CurrentLanguage: Integer;
    begin
        CurrentLanguage := GlobalLanguage();
        GlobalLanguage(Language.GetDefaultApplicationLanguageId());

        TelemetryDimensions.Add('IsDefault', Format(IsNullGuid(EmailViewPolicy."User Security ID")));
        TelemetryDimensions.Add('ViewPolicy', Format(EmailViewPolicy."Email View Policy"));

        GlobalLanguage(CurrentLanguage);
    end;
    #endregion
}
