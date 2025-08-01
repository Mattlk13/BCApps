// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Security.User;

using System;

using System.Environment;
using System.Security.AccessControl;

/// <summary>
/// </summary>
codeunit 153 "User Permissions Impl."
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;
    Permissions = tabledata "Access Control" = rimd,
                  tabledata User = r;

    var
        SUPERTok: Label 'SUPER', Locked = true;
        SUPERPermissionErr: Label 'There should be at least one enabled ''SUPER'' user.';
        SECURITYPermissionSetTxt: Label 'SECURITY', Locked = true;

    procedure IsSuper(UserSecurityId: Guid): Boolean
    var
        DummyAccessControl: Record "Access Control";
        User: Record User;
        NullGuid: Guid;
    begin
        if User.IsEmpty() then
            exit(true);

        exit(HasUserPermissionSetAssigned(UserSecurityId, '', SUPERTok, DummyAccessControl.Scope::System, NullGuid));
    end;

    procedure RemoveSuperPermissions(UserSecurityId: Guid): Boolean
    var
        AccessControl: Record "Access Control";
    begin
        if not IsAnyoneElseDirectSuper(UserSecurityId) then
            exit(false);

        SetSuperFilters(AccessControl);
        AccessControl.SetRange("User Security ID", UserSecurityId);
        AccessControl.DeleteAll(true);

        exit(true);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Access Control", OnBeforeRenameEvent, '', false, false)]
    local procedure CheckSuperPermissionsBeforeRenameAccessControl(var Rec: Record "Access Control"; var xRec: Record "Access Control"; RunTrigger: Boolean)
    var
        EnvironmentInfo: Codeunit "Environment Information";
    begin
        if Rec.IsTemporary() then
            exit;

        if not EnvironmentInfo.IsSaaS() then
            exit;

        if not IsSuper(xRec) then
            exit;

        if IsAnyoneElseDirectSuper(Rec."User Security ID") then
            exit;

        Error(SUPERPermissionErr);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Access Control", OnBeforeDeleteEvent, '', false, false)]
    local procedure CheckSuperPermissionsBeforeDeleteAccessControl(var Rec: Record "Access Control"; RunTrigger: Boolean)
    var
        EnvironmentInfo: Codeunit "Environment Information";
    begin
        if Rec.IsTemporary() then
            exit;

        if not EnvironmentInfo.IsSaaS() then
            exit;

        if not RunTrigger then
            exit;

        if not IsSuper(Rec) then
            exit;

        if IsAnyoneElseDirectSuper(Rec."User Security ID") then
            exit;

        Error(SUPERPermissionErr);
    end;

    [EventSubscriber(ObjectType::Table, Database::User, OnBeforeModifyEvent, '', true, true)]
    local procedure CheckSuperPermissionsBeforeModifyUser(var Rec: Record User; var xRec: Record User; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;

        // First check if the record is potentially being disabled (we only want to prevent disabling the last SUPER user)
        // This prevents slow database calls in many cases such as user login.
        if (Rec.State <> Rec.State::Disabled) then
            exit;

        if not IsDirectSuper(Rec."User Security ID") then
            exit;

        if IsAnyoneElseDirectSuper(Rec."User Security ID") then
            exit;

        // Workaround since the xRec parameter is equal to Rec, when called from code.
        xRec.Get(Rec."User Security ID");

        // if the change is not disabling the only SUPER user
        if (Rec.State <> Rec.State::Disabled) or (xRec.State <> xRec.State::Enabled) then
            exit;

        Error(SUPERPermissionErr);
    end;

    [EventSubscriber(ObjectType::Table, Database::User, OnBeforeDeleteEvent, '', true, true)]
    local procedure CheckSuperPermissionsBeforeDeleteUser(var Rec: Record User; RunTrigger: Boolean)
    var
        EnvironmentInfo: Codeunit "Environment Information";
    begin
        if not EnvironmentInfo.IsSaaS() then
            exit;

        if Rec.IsTemporary() then
            exit;

        if not IsDirectSuper(Rec."User Security ID") then
            exit;

        if IsAnyoneElseDirectSuper(Rec."User Security ID") then
            exit;

        Error(SUPERPermissionErr);
    end;

    local procedure SetSuperFilters(var AccessControlRec: Record "Access Control")
    begin
        AccessControlRec.SetRange("Role ID", SUPERTok);
        AccessControlRec.SetFilter("Company Name", '='''''); // Company Name value is an empty string
    end;

    local procedure IsSuper(var AccessControlRec: Record "Access Control"): Boolean
    begin
        exit((AccessControlRec."Role ID" = SUPERTok) and (AccessControlRec."Company Name" = ''));
    end;

    local procedure IsDirectSuper(UserSecurityId: Guid): Boolean
    var
        AccessControl: Record "Access Control";
        User: Record User;
    begin
        if User.IsEmpty() then
            exit(true);

        AccessControl.SetRange("User Security ID", UserSecurityId);
        SetSuperFilters(AccessControl);

        exit(not AccessControl.IsEmpty());
    end;

    local procedure IsAnyoneElseDirectSuper(UserSecurityId: Guid): Boolean
    var
        AccessControl: Record "Access Control";
        User: Record User;
        IsUserEnabled: Boolean;
        IsSecurityGroup: Boolean;
    begin
        if User.IsEmpty() then
            exit(true);

        AccessControl.LockTable();
        AccessControl.SetFilter("User Security ID", '<>%1', UserSecurityId);
        SetSuperFilters(AccessControl);

        if AccessControl.IsEmpty() then // no other user is SUPER
            exit(false);

        if AccessControl.FindSet() then
            repeat
                if User.Get(AccessControl."User Security ID") then begin
                    IsUserEnabled := (User.State = User.State::Enabled);
                    IsSecurityGroup := (User."License Type" = User."License Type"::"AAD Group") or (User."License Type" = User."License Type"::"Windows Group");
                    if IsUserEnabled and (not IsSyncDaemon(User)) and (not IsSecurityGroup) then
                        exit(true);
                end;
            until AccessControl.Next() = 0;

        exit(false);
    end;

    local procedure IsSyncDaemon(User: Record User): Boolean
    begin
        // Sync Daemon is the only user with license "External User"
        exit(User."License Type" = User."License Type"::"External User");
    end;

    procedure CanManageUsersOnTenant(UserSID: Guid) Result: Boolean
    var
        DummyAccessControl: Record "Access Control";
        User: Record User;
        NullGuid: Guid;
    begin
        if User.IsEmpty() then
            exit(true);

        OnCanManageUsersOnTenant(UserSID, Result);
        if Result then
            exit;

        if IsSuper(UserSID) then
            exit(true);

        exit(HasUserPermissionSetAssigned(UserSID, CompanyName(), SECURITYPermissionSetTxt, DummyAccessControl.Scope::System, NullGuid));
    end;


    procedure HasUserPermissionSetAssigned(UserSecurityId: Guid; Company: Text; RoleId: Code[20]; ItemScope: Option; AppId: Guid): Boolean
    var
        User: Record User;
        NavUserAccountHelper: DotNet NavUserAccountHelper;
    begin
        if HasUserPermissionSetDirectlyAssigned(UserSecurityId, Company, RoleId, ItemScope, AppId) then
            exit(true);

        // NavUserAccountHelper doesn't work with bulk (buffered) inserts.
        // Calling a Get flushes the buffer.
        if not User.Get(UserSecurityId) then
            exit(false);

        if NavUserAccountHelper.IsPermissionSetAssigned(UserSecurityId, '', RoleId, AppId, ItemScope) then
            exit(true);

        if Company <> '' then
            exit(NavUserAccountHelper.IsPermissionSetAssigned(UserSecurityId, Company, RoleId, AppId, ItemScope));

        exit(false);
    end;

    procedure HasUserPermissionSetDirectlyAssigned(UserSecurityId: Guid; Company: Text; RoleId: Code[20]; ItemScope: Option; AppId: Guid): Boolean
    var
        AccessControl: Record "Access Control";
    begin
        AccessControl.SetRange("User Security ID", UserSecurityId);
        AccessControl.SetRange("Role ID", RoleId);
        AccessControl.SetFilter("Company Name", '%1|%2', '', Company);
        AccessControl.SetRange(Scope, ItemScope);
        AccessControl.SetRange("App ID", AppId);

        exit(not AccessControl.IsEmpty());
    end;

    internal procedure GetEffectivePermission(UserSecurityIdToCheck: Guid; CompanyNameToCheck: Text; PermissionObjectType: Option "Table Data","Table",,"Report",,"Codeunit","XMLport",MenuSuite,"Page","Query","System",,,,,,,,,; ObjectId: Integer): Text
    var
        NavUserAccountHelper: DotNet NavUserAccountHelper;
    begin
        exit(NavUserAccountHelper.GetEffectivePermissionForObject(UserSecurityIdToCheck, CompanyNameToCheck, PermissionObjectType, ObjectId));
    end;

    procedure GetEffectivePermission(PermissionObjectType: Option "Table Data","Table",,"Report",,"Codeunit","XMLport",MenuSuite,"Page","Query","System",,,,,,,,,; ObjectId: Integer) TempExpandedPermission: Record "Expanded Permission" temporary
    var
        PermissionMask: Text;
    begin
        TempExpandedPermission."Object Type" := PermissionObjectType;
        TempExpandedPermission."Object ID" := ObjectId;
        PermissionMask := GetEffectivePermission(UserSecurityId(), CompanyName(), PermissionObjectType, ObjectId);
        Evaluate(TempExpandedPermission."Read Permission", SelectStr(1, PermissionMask));
        Evaluate(TempExpandedPermission."Insert Permission", SelectStr(2, PermissionMask));
        Evaluate(TempExpandedPermission."Modify Permission", SelectStr(3, PermissionMask));
        Evaluate(TempExpandedPermission."Delete Permission", SelectStr(4, PermissionMask));
        Evaluate(TempExpandedPermission."Execute Permission", SelectStr(5, PermissionMask));
    end;

    procedure AssignPermissionSets(var UserSecurityId: Guid; CompanyName: Text; var AggregatePermissionSet: Record "Aggregate Permission Set")
    begin
        if not AggregatePermissionSet.FindSet() then
            exit;

        repeat
            AssignPermissionSet(UserSecurityId, CompanyName, AggregatePermissionSet);
        until AggregatePermissionSet.Next() = 0;
    end;

    procedure AssignPermissionSet(var UserSecurityId: Guid; CompanyName: Text; var AggregatePermissionSet: Record "Aggregate Permission Set")
    var
        AccessControl: Record "Access Control";
    begin
        if AccessControl.Get(UserSecurityId, AggregatePermissionSet."Role ID", '', AggregatePermissionSet.Scope, AggregatePermissionSet."App ID") then
            exit;

        AccessControl."App ID" := AggregatePermissionSet."App ID";
        AccessControl."User Security ID" := UserSecurityId;
        AccessControl."Role ID" := AggregatePermissionSet."Role ID";
        AccessControl.Scope := AggregatePermissionSet.Scope;
#pragma warning disable AA0139
        AccessControl."Company Name" := CompanyName;
#pragma warning restore AA0139
        AccessControl.Insert();
    end;

    /// <summary>
    /// An event that indicates that subscribers should set the result that should be returned when the CanManageUsersOnTenant is called.
    /// </summary>
    /// <remarks>
    /// Subscribe to this event from tests if you need to verify a different flow.
    /// This feature is for testing and is subject to a different SLA than production features.
    /// Do not use this event in a production environment. This should be subscribed to only in tests.
    /// </remarks>
    [InternalEvent(false)]
    local procedure OnCanManageUsersOnTenant(UserSID: Guid; var Result: Boolean)
    begin
    end;
}