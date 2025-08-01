// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

/// <summary>
/// Enum Shpfy Customer Mapping (ID 30106) implements Interface Shpfy ICustomer Mapping.
/// </summary>
enum 30106 "Shpfy Customer Mapping" implements "Shpfy ICustomer Mapping"
{
    Caption = 'Shopify Customer Mapping';
    Extensible = true;

    value(0; "By EMail/Phone")
    {
        Caption = 'By EMail/Phone';
        Implementation = "Shpfy ICustomer Mapping" = "Shpfy Cust. By Email/Phone";
    }
    value(1; "By Bill-to Info")
    {
        Caption = 'By Bill-to Info';
        Implementation = "Shpfy ICustomer Mapping" = "Shpfy Cust. By Bill-to";
    }
    value(2; DefaultCustomer)
    {
        Caption = 'Always take the default customer';
        Implementation = "Shpfy ICustomer Mapping" = "Shpfy Cust. By Default Cust.";
    }

}
