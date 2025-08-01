namespace Microsoft.SubscriptionBilling;

using System.Security.User;
using Microsoft.Utilities;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.GeneralLedger.Ledger;

#pragma warning disable AA0210
codeunit 139912 "Customer Deferrals Test"
{
    Subtype = Test;
    TestPermissions = Disabled;
    Access = Internal;

    var
        BillingLine: Record "Billing Line";
        BillingTemplate: Record "Billing Template";
        CurrExchRate: Record "Currency Exchange Rate";
        Customer: Record Customer;
        CustomerContract: Record "Customer Subscription Contract";
        CustomerContractDeferral: Record "Cust. Sub. Contract Deferral";
        SalesCrMemoDeferral: Record "Cust. Sub. Contract Deferral";
        SalesInvoiceDeferral: Record "Cust. Sub. Contract Deferral";
        GLSetup: Record "General Ledger Setup";
        GeneralPostingSetup: Record "General Posting Setup";
        Item: Record Item;
        ItemServCommitmentPackage: Record "Item Subscription Package";
        SalesCrMemoHeader: Record "Sales Header";
        SalesHeader: Record "Sales Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        SalesLine: Record "Sales Line";
        ServiceCommPackageLine: Record "Subscription Package Line";
        ServiceCommitmentPackage: Record "Subscription Package";
        ServiceCommitmentTemplate: Record "Sub. Package Line Template";
        ServiceObject: Record "Subscription Header";
        UserSetup: Record "User Setup";
        Assert: Codeunit Assert;
        ContractTestLibrary: Codeunit "Contract Test Library";
        CorrectPostedSalesInvoice: Codeunit "Correct Posted Sales Invoice";
        LibraryTestInitialize: Codeunit "Library - Test Initialize";
        LibraryRandom: Codeunit "Library - Random";
        LibrarySales: Codeunit "Library - Sales";
        CorrectedDocumentNo: Code[20];
        PostedDocumentNo: Code[20];
        PostingDate: Date;
        DeferralBaseAmount: Decimal;
        FirstMonthDefBaseAmount: Decimal;
        LastMonthDefBaseAmount: Decimal;
        MonthlyDefBaseAmount: Decimal;
        CustomerDeferralsCount: Integer;
        PrevGLEntry: Integer;
        TotalNumberOfMonths: Integer;
        IsInitialized: Boolean;
        ConfirmQuestionLbl: Label 'If you change Quantity, only the Amount for existing service commitments will be recalculated.\\Do you want to continue?', Comment = '%1= Changed Field Name.';

    #region Tests

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure CheckContractDeferralsWhenStartDateIsNotOnFirstDayInMonthCalculatedForFullYearFCY()
    var
        CustomerDeferralCount: Integer;
        i: Integer;
    begin
        Initialize();
        SetSalesDocumentAndCustomerContractDeferrals('<-CY+14D>', '<CY+14D>', false, 11, CustomerDeferralCount);
        for i := 1 to CustomerDeferralCount do begin
            TestCustomerContractDeferralsFields();
            CustomerContractDeferral.TestField(
                "Deferral Base Amount",
                Round(
                    CurrExchRate.ExchangeAmtFCYToLCY(SalesHeader."Posting Date", SalesHeader."Currency Code", DeferralBaseAmount * -1, SalesHeader."Currency Factor"), GLSetup."Amount Rounding Precision"));
            case i of
                1:
                    begin
                        CustomerContractDeferral.TestField(Amount, FirstMonthDefBaseAmount * -1);
                        CustomerContractDeferral.TestField("Number of Days", 17);
                    end;
                CustomerDeferralCount:
                    begin
                        CustomerContractDeferral.TestField(Amount, LastMonthDefBaseAmount * -1);
                        CustomerContractDeferral.TestField("Number of Days", 14);
                    end;
                else begin
                    CustomerContractDeferral.TestField(Amount, MonthlyDefBaseAmount * -1);
                    CustomerContractDeferral.TestField("Number of Days", Date2DMY(CalcDate('<CM>', CustomerContractDeferral."Posting Date"), 1));
                end;
            end;
            CustomerContractDeferral.Next();
        end;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure CheckContractDeferralsWhenStartDateIsNotOnFirstDayInMonthCalculatedForFullYearLCY()
    var
        CustomerDeferralCount: Integer;
        i: Integer;
    begin
        Initialize();
        SetSalesDocumentAndCustomerContractDeferrals('<-CY+14D>', '<CY+14D>', true, 11, CustomerDeferralCount);
        for i := 1 to CustomerDeferralCount do begin
            TestCustomerContractDeferralsFields();
            CustomerContractDeferral.TestField("Deferral Base Amount", DeferralBaseAmount * -1);
            case i of
                1:
                    begin
                        CustomerContractDeferral.TestField(Amount, FirstMonthDefBaseAmount * -1);
                        CustomerContractDeferral.TestField("Number of Days", 17);
                    end;
                CustomerDeferralCount:
                    begin
                        CustomerContractDeferral.TestField(Amount, LastMonthDefBaseAmount * -1);
                        CustomerContractDeferral.TestField("Number of Days", 14);
                    end;
                else begin
                    CustomerContractDeferral.TestField(Amount, MonthlyDefBaseAmount * -1);
                    CustomerContractDeferral.TestField("Number of Days", Date2DMY(CalcDate('<CM>', CustomerContractDeferral."Posting Date"), 1));
                end;
            end;
            CustomerContractDeferral.Next();
        end;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure CheckContractDeferralsWhenStartDateIsNotOnFirstDayInMonthCalculatedForPartialYearFCY()
    var
        CustomerDeferralCount: Integer;
        i: Integer;
    begin
        Initialize();
        SetSalesDocumentAndCustomerContractDeferrals('<-CY+14D>', '<CY-1M-9D>', false, 9, CustomerDeferralCount);
        for i := 1 to CustomerDeferralCount do begin
            TestCustomerContractDeferralsFields();
            CustomerContractDeferral.TestField(
                "Deferral Base Amount",
                CurrExchRate.ExchangeAmtFCYToLCY(SalesHeader."Posting Date", SalesHeader."Currency Code", DeferralBaseAmount * -1, SalesHeader."Currency Factor"));
            case i of
                1:
                    begin
                        CustomerContractDeferral.TestField(Amount, FirstMonthDefBaseAmount * -1);
                        CustomerContractDeferral.TestField("Number of Days", 17);
                    end;
                CustomerDeferralCount:
                    begin
                        CustomerContractDeferral.TestField(Amount, LastMonthDefBaseAmount * -1);
                        CustomerContractDeferral.TestField("Number of Days", 21);
                    end;
                else begin
                    CustomerContractDeferral.TestField(Amount, MonthlyDefBaseAmount * -1);
                    CustomerContractDeferral.TestField("Number of Days", Date2DMY(CalcDate('<CM>', CustomerContractDeferral."Posting Date"), 1));
                end;
            end;
            CustomerContractDeferral.Next();
        end;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure CheckContractDeferralsWhenStartDateIsNotOnFirstDayInMonthCalculatedForPartialYearLCY()
    var
        CustomerDeferralCount: Integer;
        i: Integer;
    begin
        Initialize();
        SetSalesDocumentAndCustomerContractDeferrals('<-CY+14D>', '<CY-1M-9D>', true, 9, CustomerDeferralCount);
        for i := 1 to CustomerDeferralCount do begin
            TestCustomerContractDeferralsFields();
            CustomerContractDeferral.TestField("Deferral Base Amount", DeferralBaseAmount * -1);
            case i of
                1:
                    begin
                        CustomerContractDeferral.TestField(Amount, FirstMonthDefBaseAmount * -1);
                        CustomerContractDeferral.TestField("Number of Days", 17);
                    end;
                CustomerDeferralCount:
                    begin
                        CustomerContractDeferral.TestField(Amount, LastMonthDefBaseAmount * -1);
                        CustomerContractDeferral.TestField("Number of Days", 21);
                    end;
                else begin
                    CustomerContractDeferral.TestField(Amount, MonthlyDefBaseAmount * -1);
                    CustomerContractDeferral.TestField("Number of Days", Date2DMY(CalcDate('<CM>', CustomerContractDeferral."Posting Date"), 1));
                end;
            end;
            CustomerContractDeferral.Next();
        end;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler,ExchangeRateSelectionModalPageHandler')]
    procedure CheckContractDeferralsWhenStartDateIsOnFirstDayInMonthCalculatedForFullYearFCY()
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<-CY>', false);
        CreateBillingProposalAndCreateBillingDocuments('<-CY>', '<CY>');

        DeferralBaseAmount := GetDeferralBaseAmount();
        PostSalesDocumentAndFetchDeferrals();
        repeat
            TestCustomerContractDeferralsFields();
            CustomerContractDeferral.TestField(
                Amount,
                Round(CurrExchRate.ExchangeAmtFCYToLCY(SalesHeader."Posting Date", SalesHeader."Currency Code", -5, SalesHeader."Currency Factor"), GLSetup."Amount Rounding Precision"));
            CustomerContractDeferral.TestField(
                "Deferral Base Amount",
                Round(CurrExchRate.ExchangeAmtFCYToLCY(SalesHeader."Posting Date", SalesHeader."Currency Code", -60, SalesHeader."Currency Factor"), GLSetup."Amount Rounding Precision"));
            CustomerContractDeferral.TestField("Number of Days", Date2DMY(CalcDate('<CM>', CustomerContractDeferral."Posting Date"), 1));
        until CustomerContractDeferral.Next() = 0;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure CheckContractDeferralsWhenStartDateIsOnFirstDayInMonthCalculatedForFullYearLCY()
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<-CY>', true);
        CreateBillingProposalAndCreateBillingDocuments('<-CY>', '<CY>');

        PostSalesDocumentAndFetchDeferrals();
        repeat
            TestCustomerContractDeferralsFields();
            CustomerContractDeferral.TestField(Amount, -10);
            CustomerContractDeferral.TestField("Deferral Base Amount", -120);
            CustomerContractDeferral.TestField("Number of Days", Date2DMY(CalcDate('<CM>', CustomerContractDeferral."Posting Date"), 1));
        until CustomerContractDeferral.Next() = 0;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure DeferralsAreCorrectAfterPostingPartialSalesCreditMemo()
    begin
        Initialize();
        // [SCENARIO] Making sure that Credit Memo Deferrals are created only for existing Credit Memo Lines
        // [SCENARIO] Posted Invoice contains two lines connected for a contract.
        // [SCENARIO] Credit Memo is created for Posted Invoice and one of the lines in a credit memo is deleted.
        // [SCENARIO] Deferral Entries releasing a single invoice line should be created and not for all invoice lines

        // [GIVEN] Contract has been created and the billing proposal with non posted contract invoice
        CreateCustomerContractWithDeferrals('<2M-CM>', true, 2, false);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');

        // [WHEN] Post the contract invoice and a credit memo crediting only the first invoice line
        PostSalesDocumentAndGetSalesInvoice();
        CorrectPostedSalesInvoice.CreateCreditMemoCopyDocument(SalesInvoiceHeader, SalesCrMemoHeader);
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        SalesInvoiceLine.SetFilter("Subscription Contract Line No.", '<>0');
        SalesInvoiceLine.FindLast();
        SalesLine.SetRange("Document No.", SalesCrMemoHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.FindLast();
        SalesLine.Delete(false);
        CorrectedDocumentNo := LibrarySales.PostSalesDocument(SalesCrMemoHeader, true, true);

        // [THEN] Matching Deferral entries have been created for the first invoice line but not for the second invoice line
        FetchCustomerContractDeferrals(CorrectedDocumentNo);
        SalesInvoiceLine.FindFirst();
        CustomerContractDeferral.SetRange("Subscription Contract Line No.", SalesInvoiceLine."Subscription Contract Line No.");
        Assert.RecordIsNotEmpty(CustomerContractDeferral);
        SalesInvoiceLine.FindLast();
        CustomerContractDeferral.SetRange("Subscription Contract Line No.", SalesInvoiceLine."Subscription Contract Line No.");
        Assert.RecordIsEmpty(CustomerContractDeferral);
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,ContractDeferralsReleaseRequestPageHandler,MessageHandler')]
    procedure ExpectAmountOnContractDeferralAccountToBeZero()
    var
        ContractDeferralsRelease: Report "Contract Deferrals Release";
        FinalGLAmount: Decimal;
        GLAmountAfterInvoicing: Decimal;
        GLAmountAfterRelease: Decimal;
        StartingGLAmount: Decimal;
    begin
        Initialize();
        SetPostingAllowTo(0D);
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');

        GeneralPostingSetup.Get(Customer."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group");

        // After crediting expect this amount to be on GL Entry
        GetGLEntryAmountFromAccountNo(StartingGLAmount, GeneralPostingSetup."Cust. Sub. Contr. Def Account");

        // Release only first Customer Subscription Contract Deferral
        PostSalesDocumentAndFetchDeferrals();
        PostingDate := CustomerContractDeferral."Posting Date";
        GetGLEntryAmountFromAccountNo(GLAmountAfterInvoicing, GeneralPostingSetup."Cust. Sub. Contr. Def Account");

        // Expect Amount on GL Account to be decreased by Released Customer Deferral
        ContractDeferralsRelease.Run();  // ContractDeferralsReleaseRequestPageHandler
        GetGLEntryAmountFromAccountNo(GLAmountAfterRelease, GeneralPostingSetup."Cust. Sub. Contr. Def Account");
        Assert.AreEqual(GLAmountAfterInvoicing - CustomerContractDeferral.Amount, GLAmountAfterRelease, 'Amount was not moved from Deferrals Account to Contract Account');

        SalesInvoiceHeader.Get(PostedDocumentNo);
        PostSalesCreditMemo();

        GetGLEntryAmountFromAccountNo(FinalGLAmount, GeneralPostingSetup."Cust. Sub. Contr. Def Account");
        Assert.AreEqual(StartingGLAmount, FinalGLAmount, 'Released Contract Deferrals where not reversed properly.');
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,ContractDeferralsReleaseRequestPageHandler,MessageHandler')]
    procedure ExpectAmountOnContractDeferralAccountToBeZeroForContractLinesWithDiscount()
    var
        GLEntry: Record "G/L Entry";
        ServiceCommitment: Record "Subscription Line";
        ContractDeferralsRelease: Report "Contract Deferrals Release";
        FinalGLAmount: Decimal;
        GLAmountAfterInvoicing: Decimal;
        GLAmountAfterRelease: Decimal;
        GLLineDiscountAmountAfterInvoicing: Decimal;
        StartingGLAmount: Decimal;
    begin
        Initialize();
        SetPostingAllowTo(0D);
        CreateCustomerContractWithDeferrals('<2M-CM>', true);

        // use discounts on Subscription Line
        ServiceCommitment.SetRange("Subscription Header No.", ServiceObject."No.");
        ServiceCommitment.FindSet();
        repeat
            ServiceCommitment.Validate("Discount %", 10);
            ServiceCommitment.Modify(false);
        until ServiceCommitment.Next() = 0;

        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');

        GeneralPostingSetup.Get(Customer."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group");
        GeneralPostingSetup.TestField("Sales Line Disc. Account");
        GLEntry.SetRange("G/L Account No.", GeneralPostingSetup."Sales Line Disc. Account");
        GLEntry.DeleteAll(false);

        // After crediting expect this amount to be on GL Entry
        GetGLEntryAmountFromAccountNo(StartingGLAmount, GeneralPostingSetup."Cust. Sub. Contr. Def Account");

        // Release only first Customer Subscription Contract Deferral
        PostSalesDocumentAndFetchDeferrals();
        PostingDate := CustomerContractDeferral."Posting Date";
        GetGLEntryAmountFromAccountNo(GLAmountAfterInvoicing, GeneralPostingSetup."Cust. Sub. Contr. Def Account");
        GetGLEntryAmountFromAccountNo(GLLineDiscountAmountAfterInvoicing, GeneralPostingSetup."Sales Line Disc. Account");
        Assert.AreEqual(0, GLLineDiscountAmountAfterInvoicing, 'There should not be amount posted into Sales Line Discount Account.');

        // Expect Amount on GL Account to be decreased by Released Customer Deferral
        ContractDeferralsRelease.Run(); // ContractDeferralsReleaseRequestPageHandler
        GetGLEntryAmountFromAccountNo(GLAmountAfterRelease, GeneralPostingSetup."Cust. Sub. Contr. Def Account");
        Assert.AreEqual(GLAmountAfterInvoicing - CustomerContractDeferral.Amount, GLAmountAfterRelease, 'Amount was not moved from Deferrals Account to Contract Account');

        SalesInvoiceHeader.Get(PostedDocumentNo);
        PostSalesCreditMemo();

        GetGLEntryAmountFromAccountNo(FinalGLAmount, GeneralPostingSetup."Cust. Sub. Contr. Def Account");
        Assert.AreEqual(StartingGLAmount, FinalGLAmount, 'Released Contract Deferrals where not reversed properly.');
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,ContractDeferralsReleaseRequestPageHandler,MessageHandler')]
    procedure ExpectAmountsToBeNullAfterPostSalesCrMemoOfReleasedDeferrals()
    var
        ContractDeferralsRelease: Report "Contract Deferrals Release";
    begin
        Initialize();
        SetPostingAllowTo(0D);
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');

        // Release only first Customer Subscription Contract Deferral
        PostSalesDocumentAndFetchDeferrals();
        PostingDate := CustomerContractDeferral."Posting Date";
        ContractDeferralsRelease.Run();  // ContractDeferralsReleaseRequestPageHandler

        SalesInvoiceHeader.Get(PostedDocumentNo);
        PostSalesCreditMemo();

        CustomerContractDeferral.SetFilter("Document No.", '%1|%2', PostedDocumentNo, CorrectedDocumentNo);
        CustomerContractDeferral.SetRange(Released, true);
        CustomerContractDeferral.CalcSums(Amount, "Discount Amount");
        Assert.AreEqual(0, CustomerContractDeferral.Amount, 'Deferrals were not corrected properly.');
        Assert.AreEqual(0, CustomerContractDeferral."Discount Amount", 'Deferrals were not corrected properly.');
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure ExpectAmountsToBeNullOnAfterPostSalesCrMemo()
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        PostSalesDocumentAndGetSalesInvoice();
        PostSalesCreditMemo();

        SalesCrMemoDeferral.SetRange("Document No.", CorrectedDocumentNo);
        SalesInvoiceDeferral.SetRange("Document No.", PostedDocumentNo);
        Assert.AreEqual(SalesInvoiceDeferral.Count, SalesCrMemoDeferral.Count, 'Deferrals were not corrected properly.');

        CustomerContractDeferral.SetFilter("Document No.", '%1|%2', PostedDocumentNo, CorrectedDocumentNo);
        CustomerContractDeferral.SetRange(Released, true);
        CustomerContractDeferral.CalcSums(Amount, "Discount Amount");
        Assert.AreEqual(0, CustomerContractDeferral.Amount, 'Deferrals were not corrected properly.');
        Assert.AreEqual(0, CustomerContractDeferral."Discount Amount", 'Deferrals were not corrected properly.');
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure ExpectEqualBillingMonthsNumberAndCustContractDeferrals()
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        CalculateNumberOfBillingMonths();
        PostSalesDocumentAndGetSalesInvoice();

        CustomerContractDeferral.Reset();
        CustomerContractDeferral.SetRange("Document No.", PostedDocumentNo);
        CustomerDeferralsCount := CustomerContractDeferral.Count;
        Assert.AreEqual(CustomerDeferralsCount, TotalNumberOfMonths, 'Number of Customer deferrals must be the same as total number of billing months');
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]

    procedure ExpectErrorIfDeferralsExistOnAfterPostSalesDocumentWODeferrals()
    begin
        Initialize();
        CreateSalesDocumentsFromCustomerContractWODeferrals();
        asserterror PostSalesDocumentAndFetchDeferrals();
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure ExpectErrorOnPostSalesDocumentWithDeferralsWOGeneralPostingSetup()
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet() then
            repeat
                ContractTestLibrary.SetGeneralPostingSetup(SalesLine."Gen. Bus. Posting Group", SalesLine."Gen. Prod. Posting Group", true, Enum::"Service Partner"::Customer);
            until SalesLine.Next() = 0;
        asserterror LibrarySales.PostSalesDocument(SalesHeader, true, true);
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure ExpectErrorOnPreviewPostSalesDocumentWithDeferrals()
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        asserterror LibrarySales.PreviewPostSalesDocument(SalesHeader);
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure ExpectThatDeferralsForSalesCreditMemoAreCreatedOnce()
    var
        CopyDocumentMgt: Codeunit "Copy Document Mgt.";
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        PostSalesDocumentAndGetSalesInvoice();

        PostSalesCreditMemo();
        FetchCustomerContractDeferrals(CorrectedDocumentNo);

        SalesCrMemoHeader.Init();
        SalesCrMemoHeader.Validate("Document Type", SalesCrMemoHeader."Document Type"::"Credit Memo");
        SalesCrMemoHeader.Validate("Sell-to Customer No.", SalesInvoiceHeader."Sell-to Customer No.");
        SalesCrMemoHeader.Insert(true);

        CopyDocumentMgt.CopySalesDoc(Enum::"Sales Document Type From"::"Posted Invoice", SalesInvoiceHeader."No.", SalesCrMemoHeader);
        CorrectedDocumentNo := LibrarySales.PostSalesDocument(SalesCrMemoHeader, true, true);
        asserterror FetchCustomerContractDeferrals(CorrectedDocumentNo);
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,ContractDeferralsReleaseRequestPageHandler,MessageHandler')]
    procedure TestCorrectReleasedSalesInvoiceDeferrals()
    var
        GLEntry: Record "G/L Entry";
        ContractDeferralsRelease: Report "Contract Deferrals Release";
    begin
        Initialize();
        // Step 1 Create contract invoice with deferrals
        // Step 2 Release deferrals
        // Step 3 Correct posted sales invoice
        // Expectation:
        // -Customer Subscription Contract Deferrals with opposite sign are created
        // -Invoice Contract Deferrals are released
        // -Credit Memo Contract Deferrals are released
        // -GL Entries are posted on the Credit Memo Posting date
        SetPostingAllowTo(0D);
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        PostSalesDocumentAndFetchDeferrals();

        PostingDate := CustomerContractDeferral."Posting Date"; // Used in request page handler
        ContractDeferralsRelease.Run(); // ContractDeferralsReleaseRequestPageHandler
        SalesInvoiceHeader.Get(PostedDocumentNo);
        CorrectPostedSalesInvoice.CreateCreditMemoCopyDocument(SalesInvoiceHeader, SalesCrMemoHeader);
        PostingDate := SalesCrMemoHeader."Posting Date";
        CorrectedDocumentNo := LibrarySales.PostSalesDocument(SalesCrMemoHeader, true, true);

        CustomerContractDeferral.Reset();
        CustomerContractDeferral.SetRange("Document No.", CorrectedDocumentNo, PostedDocumentNo);
        CustomerContractDeferral.SetRange(Released, false);
        asserterror CustomerContractDeferral.FindFirst();

        GLEntry.Reset();
        GLEntry.SetRange("Document No.", CorrectedDocumentNo);
        if GLEntry.FindSet() then
            repeat
                GLEntry.TestField("Posting Date", PostingDate);
            until GLEntry.Next() = 0;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure TestIfDeferralsExistOnAfterPostSalesCreditMemo()
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        PostSalesDocumentAndGetSalesInvoice();
        PostSalesCreditMemo();
        FetchCustomerContractDeferrals(CorrectedDocumentNo);
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure TestIfDeferralsExistOnAfterPostSalesCreditMemoWithoutAppliesToDocNo()
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        PostSalesDocumentAndGetSalesInvoice();

        CorrectPostedSalesInvoice.CreateCreditMemoCopyDocument(SalesInvoiceHeader, SalesCrMemoHeader);
        // Force Applies to Doc No. and Doc Type to be empty
        SalesCrMemoHeader."Applies-to Doc. Type" := SalesCrMemoHeader."Applies-to Doc. Type"::Invoice;
        SalesCrMemoHeader."Applies-to Doc. No." := '';
        SalesCrMemoHeader.Modify(false);
        CorrectedDocumentNo := LibrarySales.PostSalesDocument(SalesCrMemoHeader, true, true);
        FetchCustomerContractDeferrals(CorrectedDocumentNo);
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure TestIfDeferralsExistOnAfterPostSalesDocument()
    begin
        Initialize();
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        PostSalesDocumentAndFetchDeferrals();
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,ContractDeferralsReleaseRequestPageHandler,MessageHandler')]
    procedure TestReleasingCustomerContractDeferrals()
    var
        GLEntry: Record "G/L Entry";
        ContractDeferralsRelease: Report "Contract Deferrals Release";
    begin
        Initialize();
        // [SCENARIO] Making sure that Deferrals are properly released and contain Contract No. on GLEntries

        // [GIVEN] Contract has been created and the billing proposal with non posted contract invoice
        SetPostingAllowTo(0D);
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');

        // [WHEN] Post the contract invoice
        PostSalesDocumentAndFetchDeferrals();

        // [THEN] Releasing each deferral entry should be correct
        repeat
            PostingDate := CustomerContractDeferral."Posting Date";
            ContractDeferralsRelease.Run();  // ContractDeferralsReleaseRequestPageHandler
            CustomerContractDeferral.Get(CustomerContractDeferral."Entry No.");
            GLEntry.Get(CustomerContractDeferral."G/L Entry No.");
            GLEntry.TestField("Subscription Contract No.", CustomerContractDeferral."Subscription Contract No.");
            FetchAndTestUpdatedCustomerContractDeferral(CustomerContractDeferral);
        until CustomerContractDeferral.Next() = 0;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,ContractDeferralsReleaseRequestPageHandler,MessageHandler')]
    procedure TestReleasingCustomerContractDeferralsForCreditMemoAsDiscount()
    var
        GLEntry: Record "G/L Entry";
        ContractDeferralsRelease: Report "Contract Deferrals Release";
    begin
        Initialize();
        // [SCENARIO] Making sure that Deferrals are properly released when Credit Memo is created from a Serv. Comm Package Line marked as Discount

        // [GIVEN] Contract has been created and the billing proposal with non posted contract credit memo
        SetPostingAllowTo(0D);
        CreateCustomerContractWithDeferrals('<2M-CM>', true, 1, false);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');

        // [WHEN] Post the credit memo
        PostSalesDocumentAndFetchDeferrals();

        // [THEN] Releasing each deferral entry should be correct
        repeat
            PostingDate := CustomerContractDeferral."Posting Date";
            ContractDeferralsRelease.Run();  // ContractDeferralsReleaseRequestPageHandler
            CustomerContractDeferral.Get(CustomerContractDeferral."Entry No.");
            GLEntry.Get(CustomerContractDeferral."G/L Entry No.");
            GLEntry.TestField("Subscription Contract No.", CustomerContractDeferral."Subscription Contract No.");
            FetchAndTestUpdatedCustomerContractDeferral(CustomerContractDeferral);
        until CustomerContractDeferral.Next() = 0;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure TestSalesCrMemoDeferralsDocumentsAndDate()
    begin
        Initialize();
        SetPostingAllowTo(WorkDate());
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        PostSalesDocumentAndGetSalesInvoice();
        FetchCustomerContractDeferrals(PostedDocumentNo);
        PostSalesCreditMemoAndFetchDeferrals();
        repeat
            SalesCrMemoDeferral.TestField("Document Type", Enum::"Rec. Billing Document Type"::"Credit Memo");
            SalesCrMemoDeferral.TestField("Document No.", CorrectedDocumentNo);
            SalesCrMemoDeferral.TestField("Posting Date", CustomerContractDeferral."Posting Date");
            SalesCrMemoDeferral.TestField("Release Posting Date", SalesCrMemoHeader."Posting Date");
            CustomerContractDeferral.Next();
        until SalesCrMemoDeferral.Next() = 0;
    end;

    [Test]
    [HandlerFunctions('CreateCustomerBillingDocsContractPageHandler,MessageHandler')]
    procedure TestSalesInvoiceDeferralsOnAfterPostSalesCrMemo()
    begin
        Initialize();
        SetPostingAllowTo(WorkDate());
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');
        PostSalesDocumentAndGetSalesInvoice();
        PostSalesCreditMemoAndFetchDeferrals();

        SalesInvoiceDeferral.SetRange("Document No.", PostedDocumentNo); // Fetch updated Sales Invoice Deferral
        SalesInvoiceDeferral.FindFirst();
        TestGLEntryFields(SalesInvoiceDeferral."G/L Entry No.", SalesInvoiceDeferral);
        repeat
            TestSalesInvoiceDeferralsReleasedFields(SalesInvoiceDeferral, SalesCrMemoHeader."Posting Date");
        until SalesInvoiceDeferral.Next() = 0;
    end;

    [Test]
    procedure UT_CheckFunctionCreateContractDeferralsForSalesLine()
    var
        SalesLine2: Record "Sales Line";
        BillingLine2: Record "Billing Line";
        SubscriptionLine: Record "Subscription Line";
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
        FunctionReturnedWrongResultErr: Label 'The function for calculating if contract deferrals should be created for a sales line returned a wrong result.', Locked = true;
    begin
        // [SCENARIO] Testing that the function CreateContractDeferrals always returns the correct result
        Initialize();

        // [GIVEN] Mock Contract, Sales Line, Subscription Line and Billing Line
        MockSubscriptionContract(CustomerSubscriptionContract);
        MockSalesLine(SalesLine2);
        MockSubscriptionLineForContract(SubscriptionLine, CustomerSubscriptionContract."No.");
        MockBillingLineForSalesLineAndSubscriptionLine(BillingLine2, SalesLine2, SubscriptionLine);

        // [WHEN] "Create Contract Deferral" is set to true in Contract, "Create Contract Deferral" is set to "Contract-dependent" in Subscription Line
        SubscriptionLine."Create Contract Deferrals" := SubscriptionLine."Create Contract Deferrals"::"Contract-dependent";
        SubscriptionLine.Modify(false);

        // [THEN] Function should return correct result
        Assert.IsTrue(SalesLine2.CreateContractDeferrals(), FunctionReturnedWrongResultErr);

        // [WHEN] "Create Contract Deferral" is set to false in Contract, "Create Contract Deferral" is set to "Contract-dependent" in Subscription Line
        CustomerSubscriptionContract."Create Contract Deferrals" := false;
        CustomerSubscriptionContract.Modify(false);

        // [THEN] Function should return correct result
        Assert.IsFalse(SalesLine2.CreateContractDeferrals(), FunctionReturnedWrongResultErr);

        // [WHEN] "Create Contract Deferral" is set to false in Contract, "Create Contract Deferral" is set to Yes in Subscription Line
        SubscriptionLine."Create Contract Deferrals" := SubscriptionLine."Create Contract Deferrals"::Yes;
        SubscriptionLine.Modify(false);

        // [THEN] Function should return correct result
        Assert.IsTrue(SalesLine2.CreateContractDeferrals(), FunctionReturnedWrongResultErr);

        // [WHEN] "Create Contract Deferral" is set to true in Contract, "Create Contract Deferral" is set to No in Subscription Line
        CustomerSubscriptionContract."Create Contract Deferrals" := true;
        CustomerSubscriptionContract.Modify(false);
        SubscriptionLine."Create Contract Deferrals" := SubscriptionLine."Create Contract Deferrals"::Yes;
        SubscriptionLine.Modify(false);

        // [THEN] Function should return correct result
        Assert.IsTrue(SalesLine2.CreateContractDeferrals(), FunctionReturnedWrongResultErr);
    end;

    [Test]
    [HandlerFunctions('ConfirmHandler')]
    procedure ConfirmQuestionPriceListsServiceQuantityChanged()
    var
        SalesLine2: Record "Sales Line";
        BillingLine2: Record "Billing Line";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
    begin
        // [SCENARIO 572340] Confirm Question on Price Lists in Service Objects when Quantity is Changed.
        Initialize();

        // [GIVEN] Mock Subscription Contract.
        MockSubscriptionContract(CustomerSubscriptionContract);

        // [GIVEN] Mock Sales Line.
        MockSalesLine(SalesLine2);

        // [GIVEN] Mock Subscription Line for Contract.
        MockSubscriptionLineForContract(SubscriptionLine, CustomerSubscriptionContract."No.");

        // [GIVEN] Mock Billing Line for Sales and Subscription Line.
        MockBillingLineForSalesLineAndSubscriptionLine(BillingLine2, SalesLine2, SubscriptionLine);

        // [WHEN] Find and Validate Quantity on Subscription Header.
        SubscriptionHeader.Get(SubscriptionLine."Subscription Header No.");
        SubscriptionHeader.Validate(Quantity, SubscriptionHeader.Quantity + LibraryRandom.RandInt(2));
        SubscriptionHeader.Modify(true);
    end;

    #endregion Tests

    #region Procedures

    local procedure Initialize()
    begin
        LibraryTestInitialize.OnTestInitialize(Codeunit::"Customer Deferrals Test");
        ClearAll();
        GLSetup.Get();
        ContractTestLibrary.InitContractsApp();

        if IsInitialized then
            exit;

        LibraryTestInitialize.OnBeforeTestSuiteInitialize(Codeunit::"Customer Deferrals Test");
        IsInitialized := true;
        LibraryTestInitialize.OnAfterTestSuiteInitialize(Codeunit::"Customer Deferrals Test");
    end;

    local procedure CalculateNumberOfBillingMonths()
    var
        StartingDate: Date;
    begin
        SalesLine.SetRange("Document No.", BillingLine."Document No.");
        SalesLine.SetFilter("No.", '<>%1', '');
        SalesLine.FindSet();
        repeat
            StartingDate := SalesLine."Recurring Billing from";
            repeat
                TotalNumberOfMonths += 1;
                StartingDate := CalcDate('<1M>', StartingDate);
            until StartingDate > CalcDate('<CM>', SalesLine."Recurring Billing to");
        until SalesLine.Next() = 0;
    end;

    local procedure CreateBillingProposalAndCreateBillingDocuments(BillingDateFormula: Text; BillingToDateFormula: Text)
    begin
        ContractTestLibrary.CreateRecurringBillingTemplate(BillingTemplate, BillingDateFormula, BillingToDateFormula, '', Enum::"Service Partner"::Customer);
        ContractTestLibrary.CreateBillingProposal(BillingTemplate, Enum::"Service Partner"::Customer);
        BillingLine.SetRange("Billing Template Code", BillingTemplate.Code);
        BillingLine.SetRange(Partner, BillingLine.Partner::Customer);
        Codeunit.Run(Codeunit::"Create Billing Documents", BillingLine); // CreateCustomerBillingDocsContractPageHandler, MessageHandler
        BillingLine.FindLast();
        SalesHeader.Get(BillingLine.GetSalesDocumentTypeFromBillingDocumentType(), BillingLine."Document No.");
    end;

    local procedure CreateCustomerContractWithDeferrals(BillingDateFormula: Text; IsCustomerContractLCY: Boolean)
    begin
        CreateCustomerContractWithDeferrals(BillingDateFormula, IsCustomerContractLCY, 1, false);
    end;

    local procedure CreateCustomerContractWithDeferrals(BillingDateFormula: Text; IsCustomerContractLCY: Boolean; ServiceCommitmentCount: Integer; UseInvoicingItem: Boolean)
    var
        i: Integer;
    begin
        if IsCustomerContractLCY then
            ContractTestLibrary.CreateCustomerInLCY(Customer)
        else
            ContractTestLibrary.CreateCustomer(Customer);
        if UseInvoicingItem then
            ContractTestLibrary.CreateItemWithServiceCommitmentOption(Item, Enum::"Item Service Commitment Type"::"Invoicing Item")
        else
            ContractTestLibrary.CreateItemWithServiceCommitmentOption(Item, Enum::"Item Service Commitment Type"::"Service Commitment Item");
        Item.Validate("Unit Price", 1200);
        Item.Modify(false);

        ContractTestLibrary.CreateServiceObjectForItem(ServiceObject, Item."No.");

        ServiceObject.Validate(Quantity, 1);
        ServiceObject.SetHideValidationDialog(true);
        ServiceObject.Validate("End-User Customer No.", Customer."No.");
        ServiceObject.Modify(false);

        ContractTestLibrary.CreateServiceCommitmentTemplate(ServiceCommitmentTemplate, '<1M>', 10, Enum::"Invoicing Via"::Contract, Enum::"Calculation Base Type"::"Item Price", false);
        ContractTestLibrary.CreateServiceCommitmentPackage(ServiceCommitmentPackage);
        for i := 1 to ServiceCommitmentCount do begin
            ContractTestLibrary.CreateServiceCommitmentPackageLine(ServiceCommitmentPackage.Code, ServiceCommitmentTemplate.Code, ServiceCommPackageLine);
            ContractTestLibrary.UpdateServiceCommitmentPackageLine(ServiceCommPackageLine, '<12M>', 10, '12M', '<1M>', Enum::"Service Partner"::Customer, Item."No.");
        end;

        ContractTestLibrary.AssignItemToServiceCommitmentPackage(Item, ServiceCommitmentPackage.Code);
        ServiceCommitmentPackage.SetFilter(Code, ItemServCommitmentPackage.GetPackageFilterForItem(ServiceObject."Source No."));
        ServiceObject.InsertServiceCommitmentsFromServCommPackage(CalcDate(BillingDateFormula, WorkDate()), ServiceCommitmentPackage);

        ContractTestLibrary.CreateCustomerContractAndCreateContractLinesForItems(CustomerContract, ServiceObject, Customer."No.");
    end;

    local procedure CreateSalesDocumentsFromCustomerContractWODeferrals()
    var
        SubscriptionLine: Record "Subscription Line";
    begin
        CreateCustomerContractWithDeferrals('<2M-CM>', true);
        CreateBillingProposalAndCreateBillingDocuments('<2M-CM>', '<8M+CM>');

        CustomerContract."Create Contract Deferrals" := false;
        CustomerContract.Modify(false);

        SubscriptionLine.SetRange(Partner, SubscriptionLine.Partner::Customer);
        SubscriptionLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        SubscriptionLine.ModifyAll("Create Contract Deferrals", Enum::"Create Contract Deferrals"::No);
    end;

    local procedure FetchAndTestUpdatedCustomerContractDeferral(CustomerDeferrals: Record "Cust. Sub. Contract Deferral")
    var
        UpdatedCustomerContractDeferral: Record "Cust. Sub. Contract Deferral";
    begin
        UpdatedCustomerContractDeferral.Get(CustomerDeferrals."Entry No.");
        Assert.AreNotEqual(PrevGLEntry, UpdatedCustomerContractDeferral."G/L Entry No.", 'G/L Entry No. is not properly assigned');
        TestSalesInvoiceDeferralsReleasedFields(UpdatedCustomerContractDeferral, PostingDate);
        TestGLEntryFields(UpdatedCustomerContractDeferral."G/L Entry No.", UpdatedCustomerContractDeferral);
        PrevGLEntry := UpdatedCustomerContractDeferral."G/L Entry No.";
    end;

    local procedure FetchCustomerContractDeferrals(DocumentNo: Code[20])
    begin
        CustomerContractDeferral.Reset();
        CustomerContractDeferral.SetRange("Document No.", DocumentNo);
        CustomerContractDeferral.FindFirst();
    end;

    local procedure GetCalculatedMonthAmountsForDeferrals(SourceDeferralBaseAmount: Decimal; NumberOfPeriods: Integer; FirstDayOfBillingPeriod: Date; LastDayOfBillingPeriod: Date; CalculateInLCY: Boolean)
    var
        DailyDefBaseAmount: Decimal;
        FirstMonthDays: Integer;
        LastMonthDays: Integer;
    begin
        DailyDefBaseAmount := SourceDeferralBaseAmount / (LastDayOfBillingPeriod - FirstDayOfBillingPeriod + 1);
        if not CalculateInLCY then begin
            DailyDefBaseAmount := CurrExchRate.ExchangeAmtFCYToLCY(SalesHeader."Posting Date", SalesHeader."Currency Code", DailyDefBaseAmount, SalesHeader."Currency Factor");
            SourceDeferralBaseAmount := CurrExchRate.ExchangeAmtFCYToLCY(SalesHeader."Posting Date", SalesHeader."Currency Code", SourceDeferralBaseAmount, SalesHeader."Currency Factor");
        end;
        FirstMonthDays := CalcDate('<CM>', FirstDayOfBillingPeriod) - FirstDayOfBillingPeriod + 1;
        FirstMonthDefBaseAmount := Round(FirstMonthDays * DailyDefBaseAmount, GLSetup."Amount Rounding Precision");
        LastMonthDays := Date2DMY(LastDayOfBillingPeriod, 1);
        LastMonthDefBaseAmount := Round(LastMonthDays * DailyDefBaseAmount, GLSetup."Amount Rounding Precision");
        MonthlyDefBaseAmount := Round((SourceDeferralBaseAmount - FirstMonthDefBaseAmount - LastMonthDefBaseAmount) / NumberOfPeriods, GLSetup."Amount Rounding Precision");
        LastMonthDefBaseAmount := SourceDeferralBaseAmount - MonthlyDefBaseAmount * NumberOfPeriods - FirstMonthDefBaseAmount;
    end;

    local procedure GetDeferralBaseAmount(): Decimal
    begin
        SalesLine.Get(BillingLine.GetPurchaseDocumentTypeFromBillingDocumentType(), BillingLine."Document No.", BillingLine."Document Line No.");
        exit(SalesLine.Amount);
    end;

    local procedure GetGLEntryAmountFromAccountNo(var GlEntryAmount: Decimal; GLAccountNo: Code[20])
    var
        GLEntry: Record "G/L Entry";
    begin
        GLEntry.SetRange("G/L Account No.", GLAccountNo);
        GLEntry.CalcSums(Amount);
        GlEntryAmount := GLEntry.Amount;
    end;

    local procedure MockBillingLineForSalesLineAndSubscriptionLine(var BillingLine2: Record "Billing Line"; SalesLine2: Record "Sales Line"; SubscriptionLine: Record "Subscription Line")
    begin
        BillingLine2.InitNewBillingLine();
        BillingLine2."Document Type" := BillingLine2.GetBillingDocumentTypeFromSalesDocumentType(SalesLine2."Document Type");
        BillingLine2."Document No." := SalesLine2."Document No.";
        BillingLine2."Document Line No." := SalesLine2."Line No.";
        BillingLine2."Subscription Line Entry No." := SubscriptionLine."Entry No.";
        BillingLine2."Subscription Contract No." := SubscriptionLine."Subscription Contract No.";
        BillingLine2.Insert(false);
    end;

    local procedure MockSalesLine(var SalesLine2: Record "Sales Line")
    var
        SalesHeader2: Record "Sales Header";
    begin
        SalesHeader2.Init();
        SalesHeader2."Document Type" := SalesLine2."Document Type"::Invoice;
        SalesHeader2.Insert(true);
        SalesLine2.Init();
        SalesLine2."Document Type" := SalesLine2."Document Type"::Invoice;
        SalesLine2."Document No." := SalesHeader2."No.";
        SalesLine2."Line No." := 10000;
        SalesLine2.Insert(false);
    end;

    local procedure MockSubscriptionContract(var CustomerSubscriptionContract: Record "Customer Subscription Contract")
    begin
        CustomerSubscriptionContract.Init();
        CustomerSubscriptionContract.Insert(true);
    end;

    local procedure MockSubscriptionLineForContract(var SubscriptionLine: Record "Subscription Line"; ContractNo: Code[20])
    var
        ServiceObject2: Record "Subscription Header";
    begin
        ServiceObject2.Init();
        ServiceObject2.Insert(true);
        SubscriptionLine.Init();
        SubscriptionLine."Subscription Header No." := ServiceObject2."No.";
        SubscriptionLine."Entry No." := 0;
        SubscriptionLine.Partner := SubscriptionLine.Partner::Customer;
        SubscriptionLine."Subscription Contract No." := ContractNo;
        SubscriptionLine.Insert(false);
    end;

    local procedure PostSalesCreditMemo()
    begin
        CorrectPostedSalesInvoice.CreateCreditMemoCopyDocument(SalesInvoiceHeader, SalesCrMemoHeader);
        CorrectedDocumentNo := LibrarySales.PostSalesDocument(SalesCrMemoHeader, true, true);
    end;

    local procedure PostSalesCreditMemoAndFetchDeferrals()
    begin
        SalesInvoiceDeferral.SetRange("Document No.", PostedDocumentNo);
        SalesInvoiceDeferral.FindFirst();
        PostSalesCreditMemo();
        SalesCrMemoDeferral.SetRange("Document No.", CorrectedDocumentNo);
        SalesCrMemoDeferral.FindFirst();
    end;

    local procedure PostSalesDocumentAndFetchDeferrals()
    begin
        PostedDocumentNo := LibrarySales.PostSalesDocument(SalesHeader, true, true);
        FetchCustomerContractDeferrals(PostedDocumentNo);
    end;

    local procedure PostSalesDocumentAndGetSalesInvoice()
    begin
        PostedDocumentNo := LibrarySales.PostSalesDocument(SalesHeader, true, true);
        SalesInvoiceHeader.Get(PostedDocumentNo);
    end;

    local procedure SetPostingAllowTo(PostingTo: Date)
    begin
        if UserSetup.Get(UserId) then begin
            UserSetup."Allow Posting From" := 0D;
            UserSetup."Allow Posting To" := PostingTo;
            UserSetup.Modify(false);
        end;
        GLSetup.Get();
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := PostingTo;
        GLSetup.Modify(false);
    end;

    local procedure SetSalesDocumentAndCustomerContractDeferrals(BillingDateFormula: Text; BillingToDateFormula: Text; CalculateInLCY: Boolean; NumberOfPeriods: Integer; var CustomerDeferralCount: Integer)
    begin
        CreateCustomerContractWithDeferrals(BillingDateFormula, true);
        CreateBillingProposalAndCreateBillingDocuments(BillingDateFormula, BillingToDateFormula);

        DeferralBaseAmount := GetDeferralBaseAmount();
        PostSalesDocumentAndFetchDeferrals();
        CustomerDeferralCount := CustomerContractDeferral.Count;
        GetCalculatedMonthAmountsForDeferrals(DeferralBaseAmount, NumberOfPeriods, CalcDate(BillingDateFormula, WorkDate()), CalcDate(BillingToDateFormula, WorkDate()), CalculateInLCY);
    end;

    local procedure TestCustomerContractDeferralsFields()
    begin
        CustomerContractDeferral.TestField("Subscription Contract No.", BillingLine."Subscription Contract No.");
        CustomerContractDeferral.TestField("Document No.", PostedDocumentNo);
        CustomerContractDeferral.TestField("Customer No.", SalesHeader."Sell-to Customer No.");
        CustomerContractDeferral.TestField("Bill-to Customer No.", SalesHeader."Bill-to Customer No.");
        CustomerContractDeferral.TestField("Document Posting Date", SalesHeader."Posting Date");
    end;

    local procedure TestGLEntryFields(EntryNo: Integer; UpdatedCustomerContractDeferral: Record "Cust. Sub. Contract Deferral")
    var
        GLEntry: Record "G/L Entry";
    begin
        GLEntry.Get(EntryNo);
        GLEntry.TestField("Document No.", UpdatedCustomerContractDeferral."Document No.");
        GLEntry.TestField("Dimension Set ID", UpdatedCustomerContractDeferral."Dimension Set ID");
        GLEntry.TestField("Subscription Contract No.", UpdatedCustomerContractDeferral."Subscription Contract No.");
    end;

    local procedure TestSalesInvoiceDeferralsReleasedFields(DeferralsToTest: Record "Cust. Sub. Contract Deferral"; DocumentPostingDate: Date)
    begin
        DeferralsToTest.TestField("Release Posting Date", DocumentPostingDate);
        DeferralsToTest.TestField(Released, true);
    end;

    #endregion Procedures

    #region Handlers

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
    end;

    [ModalPageHandler]
    procedure CreateCustomerBillingDocsContractPageHandler(var CreateCustomerBillingDocs: TestPage "Create Customer Billing Docs")
    begin
        CreateCustomerBillingDocs.OK().Invoke();
    end;

    [ModalPageHandler]
    procedure ExchangeRateSelectionModalPageHandler(var ExchangeRateSelectionPage: TestPage "Exchange Rate Selection")
    begin
        ExchangeRateSelectionPage.OK().Invoke();
    end;

    [RequestPageHandler]
    procedure ContractDeferralsReleaseRequestPageHandler(var ContractDeferralsRelease: TestRequestPage "Contract Deferrals Release")
    begin
        ContractDeferralsRelease.PostingDateReq.SetValue(PostingDate);
        ContractDeferralsRelease.PostUntilDateReq.SetValue(PostingDate);
        ContractDeferralsRelease.OK().Invoke();
    end;

    [ConfirmHandler]
    procedure ConfirmHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Assert.ExpectedConfirm(ConfirmQuestionLbl, Question);
        Reply := true;
    end;

    #endregion Handlers
}
#pragma warning restore AA0210
