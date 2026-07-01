@isTest
private class EscrowJointOwnerFARQueueableTest {

    // ── Constants ────────────────────────────────────────────────────
    private static final String INDIVIDUAL_RECORDTYPE = 'Individual';
    private static final String BUSINESS_RECORDTYPE   = 'IndustriesBusiness';
    private static final String BANKING_ACCOUNT_RT    = 'BankingAccount';
    private static final String ESCROW_AGENT_ROLE     = 'Escrow Agent';
    private static final String JOINT_OWNER_ROLE      = 'Joint Owner';

    // ── Test Setup ───────────────────────────────────────────────────
    @TestSetup
    static void makeData() {
        RecordType individualRT = [
            SELECT Id FROM RecordType
            WHERE SObjectType      = 'Account'
              AND DeveloperName    = :INDIVIDUAL_RECORDTYPE
              AND NamespacePrefix  = NULL
            LIMIT 1
        ];
        RecordType businessRT = [
            SELECT Id FROM RecordType
            WHERE SObjectType   = 'Account'
              AND DeveloperName = :BUSINESS_RECORDTYPE
            LIMIT 1
        ];

        Account indvPO = new Account(
            LastName                = 'Individual PO',
            RecordTypeId            = individualRT.Id,
            PersonMailingCity       = 'San Francisco',
            PersonMailingCountry    = 'United States',
            PersonMailingPostalCode = '94109',
            PersonMailingState      = 'California',
            PersonMailingStreet     = 'Franklin',
            PersonOtherCity         = 'San Francisco',
            PersonOtherCountry      = 'United States',
            PersonOtherPostalCode   = '94109',
            PersonOtherState        = 'California',
            PersonOtherStreet       = 'Franklin',
            PersonEmail             = 'indvpo@test.com'
        );
        Account indvRA = new Account(
            LastName                = 'Individual RA',
            RecordTypeId            = individualRT.Id,
            PersonMailingCity       = 'San Francisco',
            PersonMailingCountry    = 'United States',
            PersonMailingPostalCode = '94109',
            PersonMailingState      = 'California',
            PersonMailingStreet     = 'Franklin',
            PersonOtherCity         = 'San Francisco',
            PersonOtherCountry      = 'United States',
            PersonOtherPostalCode   = '94109',
            PersonOtherState        = 'California',
            PersonOtherStreet       = 'Franklin',
            PersonEmail             = 'indvra@test.com'
        );
        Account bizPO = new Account(
            Name               = 'Business PO',
            RecordTypeId       = businessRT.Id,
            Phone              = '555-555-5551',
            BillingCity        = 'Business City',
            BillingCountry     = 'United States',
            BillingPostalCode  = '54321',
            BillingState       = 'Florida',
            BillingStreet      = '1 Business Street',
            ShippingCity       = 'Business City',
            ShippingCountry    = 'United States',
            ShippingPostalCode = '54321',
            ShippingState      = 'Florida',
            ShippingStreet     = '1 Business Street'
        );
        Account bizRA = new Account(
            Name               = 'Business RA',
            RecordTypeId       = businessRT.Id,
            Phone              = '555-555-5552',
            BillingCity        = 'Business City',
            BillingCountry     = 'United States',
            BillingPostalCode  = '54321',
            BillingState       = 'Florida',
            BillingStreet      = '1 Business Street',
            ShippingCity       = 'Business City',
            ShippingCountry    = 'United States',
            ShippingPostalCode = '54321',
            ShippingState      = 'Florida',
            ShippingStreet     = '1 Business Street'
        );
        insert new List<Account>{ indvPO, indvRA, bizPO, bizRA };

        Id accountRoleRTId = Schema.SObjectType.FinServ__ReciprocalRole__c
            .getRecordTypeInfosByDeveloperName()
            .get('AccountRole').getRecordTypeId();
        Id contactRoleRTId = Schema.SObjectType.FinServ__ReciprocalRole__c
            .getRecordTypeInfosByDeveloperName()
            .get('ContactRole').getRecordTypeId();

        insert new List<FinServ__ReciprocalRole__c>{
            new FinServ__ReciprocalRole__c(
                Name                          = 'Escrow Agent',
                FinServ__InverseRole__c       = 'Has Escrow Agent',
                FinServ__CreateInverseRole__c = true,
                RecordTypeId                  = accountRoleRTId
            ),
            new FinServ__ReciprocalRole__c(
                Name                          = 'Escrow Agent',
                FinServ__InverseRole__c       = 'Has Escrow Agent',
                FinServ__CreateInverseRole__c = true,
                RecordTypeId                  = contactRoleRTId
            ),
            new FinServ__ReciprocalRole__c(
                Name                          = 'Joint Owner',
                FinServ__InverseRole__c       = 'Has Joint Owner',
                FinServ__CreateInverseRole__c = true,
                RecordTypeId                  = accountRoleRTId
            ),
            new FinServ__ReciprocalRole__c(
                Name                          = 'Joint Owner',
                FinServ__InverseRole__c       = 'Has Joint Owner',
                FinServ__CreateInverseRole__c = true,
                RecordTypeId                  = contactRoleRTId
            )
        };
    }

    // ── Helpers ───────────────────────────────────────────────────────
    private static RecordType getFinAccRT() {
        return [
            SELECT Id FROM RecordType
            WHERE SObjectType   = 'FinServ__FinancialAccount__c'
              AND DeveloperName = :BANKING_ACCOUNT_RT
            LIMIT 1
        ];
    }

    private static Map<String, Account> getAccounts() {
        Map<String, Account> result = new Map<String, Account>();
        for (Account a : [
            SELECT Id, Name, LastName,
                   RecordType.DeveloperName,
                   PersonContactId
            FROM Account
            WHERE Name     IN ('Business PO', 'Business RA')
               OR LastName IN ('Individual PO', 'Individual RA')
        ]) {
            String key = String.isBlank(a.Name) ? a.LastName : a.Name;
            result.put(key, a);
        }
        return result;
    }

    private static FinServ__FinancialAccount__c buildFA(
        String name, Id primaryOwnerId,
        Id rtId, String specialCase
    ) {
        return new FinServ__FinancialAccount__c(
            Name                     = name,
            RecordTypeId             = rtId,
            FinServ__PrimaryOwner__c = primaryOwnerId,
            BKU_Special_Case__c      = specialCase,
            FinServ__Status__c       = 'Open'
        );
    }

    // =========================================================
    // AC1: Business PO + Individual RA + Escrow Agent → ACR
    // =========================================================
    @isTest
    static void testInsert_BusinessPrimaryOwner_IndividualEscrowAgent_CreatesACR() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA BizPO IndvRA Escrow',
            bizPO.Id, faRT.Id, 'FIDUCIARY'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA BizPO IndvRA Escrow' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = indvRA.Id,
            FinServ__Role__c             = ESCROW_AGENT_ROLE
        );
        Test.stopTest();

        List<AccountContactRelation> acrs = [
            SELECT Id, Roles FROM AccountContactRelation
            WHERE AccountId = :bizPO.Id
              AND ContactId = :indvRA.PersonContactId
        ];
        System.assertEquals(1, acrs.size(),
            'Expected 1 ACR for Business PO and Individual Escrow Agent');
        System.assert(acrs[0].Roles.contains('Escrow Agent'),
            'Escrow Agent role not set on ACR');
    }

    // =========================================================
    // AC2: Business PO + Individual RA + Joint Owner → ACR
    // =========================================================
    @isTest
    static void testInsert_BusinessPrimaryOwner_IndividualJointOwner_CreatesACR() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA BizPO IndvRA Joint',
            bizPO.Id, faRT.Id, 'IOLA/IOLTA'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA BizPO IndvRA Joint' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = indvRA.Id,
            FinServ__Role__c             = JOINT_OWNER_ROLE
        );
        Test.stopTest();

        List<AccountContactRelation> acrs = [
            SELECT Id, Roles FROM AccountContactRelation
            WHERE AccountId = :bizPO.Id
              AND ContactId = :indvRA.PersonContactId
        ];
        System.assertEquals(1, acrs.size(),
            'Expected 1 ACR for Business PO and Individual Joint Owner');
        System.assert(acrs[0].Roles.contains('Joint Owner'),
            'Joint Owner role not set on ACR');
    }

    // =========================================================
    // AC3: Individual PO + Individual RA + Escrow Agent → CCR
    // =========================================================
    @isTest
    static void testInsert_IndividualPrimaryOwner_IndividualEscrowAgent_CreatesCCR() {
        Map<String, Account> accounts = getAccounts();
        Account indvPO = accounts.get('Individual PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA IndvPO IndvRA Escrow',
            indvPO.Id, faRT.Id, 'FIDUCIARY'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA IndvPO IndvRA Escrow' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = indvRA.Id,
            FinServ__Role__c             = ESCROW_AGENT_ROLE
        );
        Test.stopTest();

        List<FinServ__ContactContactRelation__c> ccrs = [
            SELECT Id FROM FinServ__ContactContactRelation__c
            WHERE FinServ__Contact__c        = :indvRA.PersonContactId
              AND FinServ__RelatedContact__c = :indvPO.PersonContactId
        ];
        System.assertEquals(1, ccrs.size(),
            'Expected 1 CCR for Individual PO and Individual Escrow Agent');
    }

    // =========================================================
    // AC4: Individual PO + Individual RA + Joint Owner → CCR
    // =========================================================
    @isTest
    static void testInsert_IndividualPrimaryOwner_IndividualJointOwner_CreatesCCR() {
        Map<String, Account> accounts = getAccounts();
        Account indvPO = accounts.get('Individual PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA IndvPO IndvRA Joint',
            indvPO.Id, faRT.Id, 'IOLA/IOLTA'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA IndvPO IndvRA Joint' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = indvRA.Id,
            FinServ__Role__c             = JOINT_OWNER_ROLE
        );
        Test.stopTest();

        List<FinServ__ContactContactRelation__c> ccrs = [
            SELECT Id FROM FinServ__ContactContactRelation__c
            WHERE FinServ__Contact__c        = :indvRA.PersonContactId
              AND FinServ__RelatedContact__c = :indvPO.PersonContactId
        ];
        System.assertEquals(1, ccrs.size(),
            'Expected 1 CCR for Individual PO and Individual Joint Owner');
    }

    // =========================================================
    // AC5: Individual PO + Business RA + Escrow Agent → ACR
    // =========================================================
    @isTest
    static void testInsert_IndividualPrimaryOwner_BusinessEscrowAgent_CreatesACR() {
        Map<String, Account> accounts = getAccounts();
        Account indvPO = accounts.get('Individual PO');
        Account bizRA  = accounts.get('Business RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA IndvPO BizRA Escrow',
            indvPO.Id, faRT.Id, 'FIDUCIARY'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA IndvPO BizRA Escrow' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = bizRA.Id,
            FinServ__Role__c             = ESCROW_AGENT_ROLE
        );
        Test.stopTest();

        List<AccountContactRelation> acrs = [
            SELECT Id, Roles FROM AccountContactRelation
            WHERE AccountId = :bizRA.Id
              AND ContactId = :indvPO.PersonContactId
        ];
        System.assertEquals(1, acrs.size(),
            'Expected 1 ACR for Individual PO and Business Escrow Agent');
        System.assert(acrs[0].Roles.contains('Escrow Agent'),
            'Escrow Agent role not set on ACR');
    }

    // =========================================================
    // AC6: Individual PO + Business RA + Joint Owner → ACR
    // =========================================================
    @isTest
    static void testInsert_IndividualPrimaryOwner_BusinessJointOwner_CreatesACR() {
        Map<String, Account> accounts = getAccounts();
        Account indvPO = accounts.get('Individual PO');
        Account bizRA  = accounts.get('Business RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA IndvPO BizRA Joint',
            indvPO.Id, faRT.Id, 'IOLA/IOLTA'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA IndvPO BizRA Joint' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = bizRA.Id,
            FinServ__Role__c             = JOINT_OWNER_ROLE
        );
        Test.stopTest();

        List<AccountContactRelation> acrs = [
            SELECT Id, Roles FROM AccountContactRelation
            WHERE AccountId = :bizRA.Id
              AND ContactId = :indvPO.PersonContactId
        ];
        System.assertEquals(1, acrs.size(),
            'Expected 1 ACR for Individual PO and Business Joint Owner');
        System.assert(acrs[0].Roles.contains('Joint Owner'),
            'Joint Owner role not set on ACR');
    }

    // =========================================================
    // AC7: Business PO + Business RA + Escrow Agent → AAR
    // =========================================================
    @isTest
    static void testInsert_BusinessPrimaryOwner_BusinessEscrowAgent_CreatesAAR() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO = accounts.get('Business PO');
        Account bizRA = accounts.get('Business RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA BizPO BizRA Escrow',
            bizPO.Id, faRT.Id, 'FIDUCIARY'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA BizPO BizRA Escrow' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = bizRA.Id,
            FinServ__Role__c             = ESCROW_AGENT_ROLE
        );
        Test.stopTest();

        List<FinServ__AccountAccountRelation__c> aars = [
            SELECT Id, FinServ__AssociationType__c
            FROM FinServ__AccountAccountRelation__c
            WHERE FinServ__Account__c        = :bizPO.Id
              AND FinServ__RelatedAccount__c = :bizRA.Id
        ];
        System.assertEquals(1, aars.size(),
            'Expected 1 AAR for Business PO and Business Escrow Agent');
        System.assertEquals('Peer',
            aars[0].FinServ__AssociationType__c,
            'AssociationType should be Peer');
    }

    // =========================================================
    // AC8: Business PO + Business RA + Joint Owner → AAR
    // =========================================================
    @isTest
    static void testInsert_BusinessPrimaryOwner_BusinessJointOwner_CreatesAAR() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO = accounts.get('Business PO');
        Account bizRA = accounts.get('Business RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA BizPO BizRA Joint',
            bizPO.Id, faRT.Id, 'IOLA/IOLTA'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA BizPO BizRA Joint' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = bizRA.Id,
            FinServ__Role__c             = JOINT_OWNER_ROLE
        );
        Test.stopTest();

        List<FinServ__AccountAccountRelation__c> aars = [
            SELECT Id, FinServ__AssociationType__c
            FROM FinServ__AccountAccountRelation__c
            WHERE FinServ__Account__c        = :bizPO.Id
              AND FinServ__RelatedAccount__c = :bizRA.Id
        ];
        System.assertEquals(1, aars.size(),
            'Expected 1 AAR for Business PO and Business Joint Owner');
        System.assertEquals('Peer',
            aars[0].FinServ__AssociationType__c,
            'AssociationType should be Peer');
    }

    // =========================================================
    // AC9: Delete Escrow Agent FAR removes relationship
    // =========================================================
    @isTest
    static void testDelete_RemovingEscrowAgentFAR_RemovesRelationship() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA Delete Escrow',
            bizPO.Id, faRT.Id, 'FIDUCIARY'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA Delete Escrow' LIMIT 1
        ];

        FinServ__FinancialAccountRole__c far =
            new FinServ__FinancialAccountRole__c(
                FinServ__FinancialAccount__c = fa.Id,
                FinServ__RelatedAccount__c   = indvRA.Id,
                FinServ__Role__c             = ESCROW_AGENT_ROLE
            );
        insert far;

        Test.startTest();
        delete far;
        Test.stopTest();

        List<AccountContactRelation> acrs = [
            SELECT Id FROM AccountContactRelation
            WHERE AccountId = :bizPO.Id
              AND ContactId = :indvRA.PersonContactId
        ];
        System.assertEquals(0, acrs.size(),
            'ACR should be removed when Escrow Agent FAR is deleted');
    }

    // =========================================================
    // AC10: Delete Joint Owner FAR removes relationship
    // =========================================================
    @isTest
    static void testDelete_RemovingJointOwnerFAR_RemovesRelationship() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA Delete Joint',
            bizPO.Id, faRT.Id, 'IOLA/IOLTA'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA Delete Joint' LIMIT 1
        ];

        FinServ__FinancialAccountRole__c far =
            new FinServ__FinancialAccountRole__c(
                FinServ__FinancialAccount__c = fa.Id,
                FinServ__RelatedAccount__c   = indvRA.Id,
                FinServ__Role__c             = JOINT_OWNER_ROLE
            );
        insert far;

        Test.startTest();
        delete far;
        Test.stopTest();

        List<AccountContactRelation> acrs = [
            SELECT Id FROM AccountContactRelation
            WHERE AccountId = :bizPO.Id
              AND ContactId = :indvRA.PersonContactId
        ];
        System.assertEquals(0, acrs.size(),
            'ACR should be removed when Joint Owner FAR is deleted');
    }

    // =========================================================
    // GUARD: Second FAR keeps relationship alive
    // =========================================================
    @isTest
    static void testDelete_SecondFARExists_RelationshipIsPreserved() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        FinServ__FinancialAccount__c fa1 = buildFA(
            'TEST FA Guard 1', bizPO.Id, faRT.Id, 'FIDUCIARY'
        );
        FinServ__FinancialAccount__c fa2 = buildFA(
            'TEST FA Guard 2', bizPO.Id, faRT.Id, 'FIDUCIARY'
        );
        insert new List<FinServ__FinancialAccount__c>{ fa1, fa2 };

        FinServ__FinancialAccountRole__c far1 =
            new FinServ__FinancialAccountRole__c(
                FinServ__FinancialAccount__c = fa1.Id,
                FinServ__RelatedAccount__c   = indvRA.Id,
                FinServ__Role__c             = ESCROW_AGENT_ROLE
            );
        FinServ__FinancialAccountRole__c far2 =
            new FinServ__FinancialAccountRole__c(
                FinServ__FinancialAccount__c = fa2.Id,
                FinServ__RelatedAccount__c   = indvRA.Id,
                FinServ__Role__c             = ESCROW_AGENT_ROLE
            );
        insert new List<FinServ__FinancialAccountRole__c>{ far1, far2 };

        Test.startTest();
        delete far1;
        Test.stopTest();

        List<AccountContactRelation> acrs = [
            SELECT Id FROM AccountContactRelation
            WHERE AccountId = :bizPO.Id
              AND ContactId = :indvRA.PersonContactId
        ];
        System.assertEquals(1, acrs.size(),
            'ACR should remain because second FAR still exists');
    }

    // =========================================================
    // NEGATIVE: Non-qualifying role ignored
    // =========================================================
    @isTest
    static void testInsert_NonEscrowJointRole_NoRelationshipCreated() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA Ignored Role',
            bizPO.Id, faRT.Id, 'FIDUCIARY'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA Ignored Role' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = indvRA.Id,
            FinServ__Role__c             = 'Other - Owner'
        );
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM AccountContactRelation
             WHERE AccountId = :bizPO.Id
               AND ContactId = :indvRA.PersonContactId],
            'No relationship for non-qualifying role');
    }

    // =========================================================
    // NEGATIVE: Non-Deposit FA ignored
    // =========================================================
    @isTest
    static void testInsert_NonDepositFinancialAccount_NoRelationshipCreated() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');

        RecordType loanRT = [
            SELECT Id FROM RecordType
            WHERE SObjectType   = 'FinServ__FinancialAccount__c'
              AND DeveloperName = 'AutoLoan'
            LIMIT 1
        ];
        insert new FinServ__FinancialAccount__c(
            Name                     = 'TEST FA Loan',
            RecordTypeId             = loanRT.Id,
            FinServ__PrimaryOwner__c = bizPO.Id,
            BKU_Special_Case__c      = 'FIDUCIARY',
            FinServ__Status__c       = 'Open'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA Loan' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = indvRA.Id,
            FinServ__Role__c             = ESCROW_AGENT_ROLE
        );
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM AccountContactRelation
             WHERE AccountId = :bizPO.Id
               AND ContactId = :indvRA.PersonContactId],
            'No relationship for non-deposit FA');
    }

    // =========================================================
    // NEGATIVE: Wrong Special Case ignored
    // =========================================================
    @isTest
    static void testInsert_WrongSpecialCase_NoRelationshipCreated() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert buildFA(
            'TEST FA Wrong SC',
            bizPO.Id, faRT.Id, 'Standard'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA Wrong SC' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = indvRA.Id,
            FinServ__Role__c             = ESCROW_AGENT_ROLE
        );
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM AccountContactRelation
             WHERE AccountId = :bizPO.Id
               AND ContactId = :indvRA.PersonContactId],
            'No relationship for wrong Special Case');
    }

    // =========================================================
    // ROLE APPEND: existing ACR gets role appended
    // =========================================================
    @isTest
    static void testInsert_ExistingACRWithOtherRole_EscrowAgentRoleAppended() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert new AccountContactRelation(
            AccountId = bizPO.Id,
            ContactId = indvRA.PersonContactId,
            Roles     = 'Power of Attorney'
        );

        insert buildFA(
            'TEST FA Append Escrow',
            bizPO.Id, faRT.Id, 'FIDUCIARY'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA Append Escrow' LIMIT 1
        ];

        Test.startTest();
        insert new FinServ__FinancialAccountRole__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__RelatedAccount__c   = indvRA.Id,
            FinServ__Role__c             = ESCROW_AGENT_ROLE
        );
        Test.stopTest();

        AccountContactRelation updatedACR = [
            SELECT Roles FROM AccountContactRelation
            WHERE AccountId = :bizPO.Id
              AND ContactId = :indvRA.PersonContactId
            LIMIT 1
        ];
        System.assert(updatedACR.Roles.contains('Escrow Agent'),
            'Escrow Agent should be appended');
        System.assert(updatedACR.Roles.contains('Power of Attorney'),
            'Existing role should be preserved');
    }

    // =========================================================
    // ROLE STRIP: delete only removes qualifying role
    // =========================================================
    @isTest
    static void testDelete_ACRHasMultipleRoles_OnlyEscrowAgentStripped() {
        Map<String, Account> accounts = getAccounts();
        Account bizPO  = accounts.get('Business PO');
        Account indvRA = accounts.get('Individual RA');
        RecordType faRT = getFinAccRT();

        insert new AccountContactRelation(
            AccountId = bizPO.Id,
            ContactId = indvRA.PersonContactId,
            Roles     = 'Power of Attorney;Escrow Agent'
        );

        insert buildFA(
            'TEST FA Strip Escrow',
            bizPO.Id, faRT.Id, 'FIDUCIARY'
        );
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE Name = 'TEST FA Strip Escrow' LIMIT 1
        ];

        FinServ__FinancialAccountRole__c far =
            new FinServ__FinancialAccountRole__c(
                FinServ__FinancialAccount__c = fa.Id,
                FinServ__RelatedAccount__c   = indvRA.Id,
                FinServ__Role__c             = ESCROW_AGENT_ROLE
            );
        insert far;

        Test.startTest();
        delete far;
        Test.stopTest();

        AccountContactRelation updatedACR = [
            SELECT Roles FROM AccountContactRelation
            WHERE AccountId = :bizPO.Id
              AND ContactId = :indvRA.PersonContactId
            LIMIT 1
        ];
        System.assert(!updatedACR.Roles.contains('Escrow Agent'),
            'Escrow Agent should be stripped');
        System.assert(updatedACR.Roles.contains('Power of Attorney'),
            'Power of Attorney should remain');
    }
}
