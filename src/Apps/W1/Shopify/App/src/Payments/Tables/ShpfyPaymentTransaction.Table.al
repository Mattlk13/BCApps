// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using Microsoft.Sales.History;

/// <summary>
/// Table Shpfy Payment Transaction (ID 30124).
/// </summary>
table 30124 "Shpfy Payment Transaction"
{
    Caption = 'Shopify Payment Transaction';
    DataClassification = CustomerContent;

    fields
    {
        field(1; Id; BigInteger)
        {
            Caption = 'Id';
            DataClassification = SystemMetadata;
        }
        field(2; Type; Enum "Shpfy Payment Trans. Type")
        {
            Caption = 'Type';
            DataClassification = CustomerContent;
        }
        field(3; Test; Boolean)
        {
            Caption = 'Test';
            DataClassification = CustomerContent;
        }
        field(4; "Payout Id"; BigInteger)
        {
            Caption = 'Payout Id';
            DataClassification = SystemMetadata;
        }
        field(5; Currency; Code[10])
        {
            Caption = 'Currency';
            DataClassification = CustomerContent;
        }
        field(6; Amount; Decimal)
        {
            Caption = 'Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
            AutoFormatExpression = Currency;
        }
        field(7; Fee; Decimal)
        {
            Caption = 'Fee';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
            AutoFormatExpression = Currency;
        }
        field(8; "Net Amount"; Decimal)
        {
            Caption = 'Net Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
            AutoFormatExpression = Currency;
        }
        field(9; "Source Id"; BigInteger)
        {
            BlankZero = true;
            Caption = 'Source Id';
            DataClassification = SystemMetadata;
        }
        field(10; "Source Type"; Enum "Shpfy Payment Trans. Type")
        {
            Caption = 'Source Type';
            DataClassification = CustomerContent;
        }
        field(11; "Source Order Transaction Id"; BigInteger)
        {
            BlankZero = true;
            Caption = 'Source Order Transaction Id';
            DataClassification = SystemMetadata;
        }
        field(12; "Source Order Id"; BigInteger)
        {
            BlankZero = true;
            Caption = 'Source Order Id';
            DataClassification = SystemMetadata;
        }
        field(13; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
            DataClassification = CustomerContent;
        }
        field(101; "Shop Code"; Code[20])
        {
            Caption = 'Shop Code';
            DataClassification = SystemMetadata;
            TableRelation = "Shpfy Shop";
        }
        field(102; "Invoice No."; Code[20])
        {
            CalcFormula = lookup("Sales Invoice Header"."No."
                          where("Shpfy Order Id" = field("Source Order Id"), "Shpfy Order Id" = filter('<>0')));
            Caption = 'Invoice No.';
            FieldClass = FlowField;
        }
    }
    keys
    {
        key(PK; Id)
        {
            Clustered = true;
        }

        key(Idx1; "Payout Id") { }
        key(Idx2; "Shop Code") { }
    }

}
