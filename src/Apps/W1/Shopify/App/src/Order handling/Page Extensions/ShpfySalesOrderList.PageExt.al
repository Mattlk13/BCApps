// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using Microsoft.Sales.Document;

/// <summary>
/// PageExtension Shpfy Sales Order List (ID 30116) extends Record Sales Order List.
/// </summary>
pageextension 30116 "Shpfy Sales Order List" extends "Sales Order List"
{
    layout
    {
        addafter("No.")
        {
            field(ShpfyOrderNo; Rec."Shpfy Order No.")
            {
                ApplicationArea = All;
                DrillDown = true;
                ToolTip = 'Specifies the order number from Shopify';
                Visible = false;

                trigger OnDrillDown()
                var
                    ShopifyOrderMgt: Codeunit "Shpfy Order Mgt.";
                    VariantRec: Variant;
                begin
                    VariantRec := Rec;
                    ShopifyOrderMgt.ShowShopifyOrder(VariantRec);
                end;
            }
#if not CLEAN25
            field(ShpfyRiskLevel; Rec."Shpfy Risk Level")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the risk level from the Shopify order.';
                Visible = false;
                ObsoleteReason = 'This field is not imported.';
                ObsoleteState = Pending;
                ObsoleteTag = '25.0';
            }
#endif
        }
    }
}