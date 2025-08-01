// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Email;

using System.DataAdministration;
using System.Reflection;
using System.Environment;
using System.Security.AccessControl;

permissionset 8900 "Email - Read"
{
    Access = Internal;
    Assignable = false;

    IncludedPermissionSets = "Email - Objects",
                             "Retention Policy - View";

    Permissions = tabledata "Email Attachments" = r,
                  tabledata "Email Connector Logo" = r,
                  tabledata "Email Error" = r,
                  tabledata "Email Message" = r,
                  tabledata "Email Message Attachment" = r,
                  tabledata "Email Outbox" = r,
                  tabledata "Email Retry" = r,
                  tabledata "Email Inbox" = r,
                  tabledata "Email Rate Limit" = r,
                  tabledata "Email Recipient" = r,
                  tabledata "Email Related Record" = r,
                  tabledata "Email Scenario" = r,
                  tabledata "Email Scenario Attachments" = r,
                  tabledata "Email View Policy" = r,
                  tabledata Field = r,
                  tabledata Media = r, // Email Account Wizard requires this
                  tabledata "Media Resources" = r,
                  tabledata "Sent Email" = r,
                  tabledata "Tenant Media" = r,
                  tabledata User = R;
}
