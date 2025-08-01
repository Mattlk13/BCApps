// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
#if not CLEANSCHEMA25
namespace Microsoft.Integration.Shopify;

table 30140 "Shpfy Templates Warnings"
{
    Access = Internal;
    TableType = Temporary;
    ObsoleteReason = 'Feature "Shopify new customer an item templates" will be enabled by default in version 25. This table is used to show warnings in Feature Management.';
    ObsoleteState = Removed;
    ObsoleteTag = '25.0';
    fields
    {
        field(1; "Template Type"; Option)
        {
            OptionMembers = "Customer","Item";
        }
        field(2; "Template Code"; Code[10])
        {
        }
        field(3; "Field Name"; Text[2048])
        {
        }
        field(4; "Field Id"; Integer)
        {
        }
        field(5; "Warning"; Text[2048])
        {
        }

    }
    keys
    {
        key(Key1; "Template Type", "Template Code", "Field Id", Warning)
        {
        }
    }
}
#endif