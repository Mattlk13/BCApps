// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Email;

using System.DataAdministration;
using System.Upgrade;
using System.Reflection;

#pragma warning disable AA0235
codeunit 1596 "Email Installer"
#pragma warning restore AA0235
{
    Subtype = Install;
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;
    Permissions = tabledata Field = r;

    trigger OnInstallAppPerCompany()
    var
        EmailViewPolicy: Codeunit "Email View Policy";
    begin
        AddRetentionPolicyAllowedTables();
        EmailViewPolicy.CheckForDefaultEntry(Enum::"Email View Policy"::AllRelatedRecordsEmails); // Default record is AllRelatedRecords for new tenants
    end;

    procedure AddRetentionPolicyAllowedTables()
    begin
        AddRetentionPolicyAllowedTables(false);
    end;

    procedure AddRetentionPolicyAllowedTables(ForceUpdate: Boolean)
    var
        Field: Record Field;
        RetenPolAllowedTables: Codeunit "Reten. Pol. Allowed Tables";
        UpgradeTag: Codeunit "Upgrade Tag";
        EmailUpgrade: Codeunit "Email Upgrade";
        IsInitialSetup: Boolean;
    begin
        IsInitialSetup := not UpgradeTag.HasUpgradeTag(EmailUpgrade.GetEmailTablesAddedToAllowedListUpgradeTag());
        if not (IsInitialSetup or ForceUpdate) then
            exit;

        RetenPolAllowedTables.AddAllowedTable(Database::"Email Outbox", Field.FieldNo(SystemCreatedAt), 7);
        RetenPolAllowedTables.AddAllowedTable(Database::"Sent Email", Field.FieldNo(SystemCreatedAt), 7);
        RetenPolAllowedTables.AddAllowedTable(Database::"Email Inbox", Field.FieldNo(SystemCreatedAt), 2);

        if IsInitialSetup then
            UpgradeTag.SetUpgradeTag(EmailUpgrade.GetEmailTablesAddedToAllowedListUpgradeTag());
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reten. Pol. Allowed Tables", OnRefreshAllowedTables, '', false, false)]
    local procedure AddAllowedTablesOnRefreshAllowedTables()
    begin
        AddRetentionPolicyAllowedTables(true);
    end;
}