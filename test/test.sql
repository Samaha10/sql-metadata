SELECT *

FROM EBH_DM_CRM.CRM_CUSTOMER C

LEFT JOIN KMR_FINANCIAL_INDEX_STAGE_01 RB_ACCT
ON RB_ACCT.CUSTOMER_ID = C.CUSTOMER_ID

LEFT JOIN KMR_FINANCIAL_INDEX_STAGE_07 OD_FAC
ON OD_FAC.CUSTOMER_ID = C.CUSTOMER_ID

LEFT JOIN KMR_FINANCIAL_INDEX_STAGE_02 CARD
ON CARD.CUSTOMER_ID = C.CUSTOMER_ID

LEFT JOIN KMR_FINANCIAL_INDEX_STAGE_03 CL_LOAN
ON CL_LOAN.CUSTOMER_ID = C.CUSTOMER_ID

LEFT JOIN KMR_FINANCIAL_INDEX_STAGE_05 CL_INV
ON CL_INV.CUSTOMER_ID = C.CUSTOMER_ID

LEFT JOIN KMR_FINANCIAL_INDEX_STAGE_04 BEF_ZRT
ON BEF_ZRT.CUSTOMER_SYMBOLS_SID = C.SYMBOLS_CUSTOMER_SID

LEFT JOIN (SELECT CA.CUSTOMER_ID,
SUM(CASE
WHEN P.KMR_TYPE_GROUP IN ('CRED_MORTG', 'CRED_HOUSE_NORM', 'CRED_HOUSE_SUBV') AND LPRE.RELATED_LOAN IS NULL AND L.ROTATION_CODE = 'N' AND CF.INVOICE_TYPE = 'PRI' THEN
CF.PAID_AMT
ELSE
0
END) AS FIN_CREDIT_MORTGAGE_AP_AMT,
SUM(CASE
WHEN P.KMR_TYPE_GROUP IN
('CRED_PERS', 'CRED_OTHER_LOMB', 'CRED_OTHER_GAR', 'CRED_OTHER_GAR_FRPR', 'CRED_OTHER_INVEST', 'CRED_OTHER_CURR', 'CRED_OTHER_SUBVINV', 'CRED_OTHER_OTHER') AND
LPRE.RELATED_LOAN IS NULL AND L.ROTATION_CODE = 'N' AND CF.INVOICE_TYPE = 'PRI' THEN
CF.PAID_AMT
ELSE
0
END) AS FIN_CREDIT_SHORT_AP_AMT
FROM SCHEMA.CRM_ARRANGEMENT AR

           JOIN SCHEMA.CRM_LOAN L
             ON L.LOAN_ID = AR.LOAN_ID
            AND L.START_OF_VALIDITY <= DATE'2020-01-01'
            AND L.END_OF_VALIDITY > DATE'2020-01-01'

           JOIN SCHEMA.CRM_CASH_FLOW CF
             ON CF.LOAN_ID = L.LOAN_ID
            AND CF.RECEIPT_DATE BETWEEN TRUNC(&GLOBAL_P_EFFECTIVE_LOAD_DATE, 'MONTH') AND &GLOBAL_P_EFFECTIVE_LOAD_DATE
            AND CF.EFFECTIVE_LOAD_DATE BETWEEN TRUNC(&GLOBAL_P_EFFECTIVE_LOAD_DATE, 'MONTH') AND DATE'2020-01-01'

           JOIN SCHEMA.CRM_REL_CUSTOMER_ARRANGEMENT CA
             ON CA.ARRANGEMENT_ID = AR.ARRANGEMENT_ID
            AND CA.START_OF_VALIDITY <= DATE'2020-01-01'
            AND CA.END_OF_VALIDITY > DATE'2020-01-01'
            AND CA.RELATION_TYPE = 'PRIMARY_CUSTOMER'

           LEFT JOIN SCHEMA.CRM_LOAN LPRE
             ON LPRE.LOAN_SID1 = L.RELATED_LOAN
            AND LPRE.START_OF_VALIDITY <= DATE'2020-01-01'
            AND LPRE.END_OF_VALIDITY > DATE'2020-01-01'

           LEFT JOIN SCHEMA.CRM_PRODUCT P
             ON P.PRODUCT = L.LOAN_CODE2
            AND P.DML <> 'D'
            AND P.START_OF_VALIDITY <= DATE'2020-01-01'
            AND P.END_OF_VALIDITY > DATE'2020-01-01'

          WHERE 1 = 1
            AND AR.START_OF_VALIDITY <= DATE'2020-01-01'
            AND AR.END_OF_VALIDITY > DATE'2020-01-01'
          GROUP BY CA.CUSTOMER_ID) QRM_ELOTORL
ON QRM_ELOTORL.CUSTOMER_ID = C.CUSTOMER_ID
LEFT JOIN (SELECT PD.CUSTOMER_ID,
CASE
WHEN MAX(PD.DAYS_PAST_DUE) > 30 THEN
MAX(PD.DAYS_PAST_DUE) - 30
ELSE
0
END AS EXP_CRED_DAYS_OVR_30_DAYS,
SUM(CASE
WHEN PD.DAYS_PAST_DUE > 30 THEN
PD.PAST_DUE_AMOUNT
ELSE
0
END) AS EXP_CRED_HUF_OVR_30_DAYS_AMT,
CASE
WHEN MAX(PD.DAYS_PAST_DUE) > 90 THEN
MAX(PD.DAYS_PAST_DUE) - 90
ELSE
0
END AS EXP_CRED_DAYS_OVR_90_DAYS,
SUM(CASE
WHEN PD.DAYS_PAST_DUE > 90 THEN
PD.PAST_DUE_AMOUNT
ELSE
0
END) AS EXP_CRED_HUF_OVR_90_DAYS_AMT,
MAX(PD.DAYS_PAST_DUE) AS EXP_CRED_DAYS,
SUM(PD.PAST_DUE_AMOUNT) AS EXP_CRED_AMT

           FROM SCHEMA.CRM_PAST_DUE PD

          WHERE 1 = 1
            AND PD.PAST_DUE_SID4 = 'FACILITY_MAX_DPD'
            AND PD.DAYS_PAST_DUE > 0
            AND PD.PAST_DUE_AMOUNT > 0
            AND PD.EFFECTIVE_LOAD_DATE = &GLOBAL_P_EFFECTIVE_LOAD_DATE
          GROUP BY PD.CUSTOMER_ID) KESEDELMEK
ON KESEDELMEK.CUSTOMER_ID = C.CUSTOMER_ID
LEFT JOIN (SELECT BLL.CUSTOMER_ID,
SUM(CASE
WHEN P.TMO_HIER_LEVEL_1 = 'HITEL' AND P.TMO_HIER_LEVEL_2 = 'MIKROVÃLLALATI HITEL' AND
(P.TMO_HIER_LEVEL_4 = 'FAKTOR' OR P.TMO_HIER_LEVEL_3 = 'KÃNYSZERHITEL' OR AR.ESTIMATED_END_DATE - L.FIRST_DISBURSEMENT_DATE <= 365) A
ND
AR.ESTIMATED_END_DATE > DAT.CALENDAR_MONTH_LAST_WORKDAY THEN
NVL(BLL.OUTSTANDING_AMT * E.EXCHANGE_RATE_VALUE, 0)
ELSE
0
END) AS FIN_CRED_OTH_SHORT_BAL,

                SUM(CASE
                      WHEN (P.TMO_HIER_LEVEL_1 = 'HITEL' AND P.TMO_HIER_LEVEL_2 = 'MIKROVÃLLALATI HITEL' AND
                           (AR.ESTIMATED_END_DATE - L.FIRST_DISBURSEMENT_DATE > 365 OR L.FIRST_DISBURSEMENT_DATE IS NULL)) AND AR.ESTIMATED_END_DATE > DAT.CALENDAR_MONTH_LAST_WORKDAY THEN
                       NVL(BLL.OUTSTANDING_AMT * E.EXCHANGE_RATE_VALUE, 0)
                      ELSE
                       0
                    END) AS FIN_CRED_OTH_LONG_BAL

           FROM SCHEMA.CRM_ARRANGEMENT AR

           JOIN SCHEMA.CRM_LOAN L
             ON L.LOAN_ID = AR.LOAN_ID
            AND L.START_OF_VALIDITY <= DATE'2020-01-01'
            AND L.END_OF_VALIDITY > DATE'2020-01-01'

           JOIN (SELECT CALENDAR_MONTH_LAST_WORKDAY
                  FROM SCHEMA.CRM_DATE DAT
                 WHERE DAT.REFERENCE_DAY = &GLOBAL_P_EFFECTIVE_LOAD_DATE
                   AND DAT.START_OF_VALIDITY <= DATE'2020-01-01'
                   AND DAT.END_OF_VALIDITY > DATE'2020-01-01'
                ) DAT
             ON 1 = 1

           LEFT JOIN SCHEMA.CRM_BALANCE_LOAN_LOAN BLL
             ON BLL.LOAN_ID = L.LOAN_ID
            AND BLL.EFFECTIVE_LOAD_DATE = DATE'2020-01-01'

           LEFT JOIN SCHEMA.CRM_EXCHANGE_RATE E
             ON E.EXCHANGE_RATE_DATE = DATE'2020-01-01'
            AND E.EFFECTIVE_LOAD_DATE = DATE'2020-01-01'
            AND E.TARGET_CURRENCY = BLL.CCY
            AND E.EXCHANGE_RATE_CODE = 'FT0'

           LEFT JOIN SCHEMA.CRM_PRODUCT P
             ON P.PRODUCT = L.LOAN_CODE2
            AND P.MODUL = 'CL'
            AND NVL(P.RB_FORCED_LOAN, '#') = '#'
            AND P.DML <> 'D'
            AND P.START_OF_VALIDITY <= DATE'2020-01-01'
            AND P.END_OF_VALIDITY > DATE'2020-01-01'

          WHERE 1 = 1
            AND AR.START_OF_VALIDITY <= DATE'2020-01-01'
            AND AR.END_OF_VALIDITY > DATE'2020-01-01'
            AND AR.ARRANGEMENT_TYPE = 'LOAN'
          GROUP BY BLL.CUSTOMER_ID) SHORT_LONG
ON SHORT_LONG.CUSTOMER_ID = C.CUSTOMER_ID
LEFT JOIN (SELECT BLE.CUSTOMER_ID, SUM(BLE.FUTURE_CAPITAL) AS FI_CRED_LEASING_BAL, COUNT(LE.LEASING_ID) AS PR_CRED_LEASING_CNT

           FROM SCHEMA.CRM_LEASING LE

           JOIN SCHEMA.CRM_BALANCE_LEASING BLE
             ON BLE.LEASING_ID = LE.LEASING_ID
            AND BLE.CUSTOMER_ID IS NOT NULL
            AND BLE.EFFECTIVE_LOAD_DATE = DATE'2020-01-01'

          WHERE 1 = 1
            AND LE.START_OF_VALIDITY <= DATE'2020-01-01'
            AND LE.END_OF_VALIDITY > DATE'2020-01-01'

          GROUP BY BLE.CUSTOMER_ID) DEALS_AND_INTERESTS
ON DEALS_AND_INTERESTS.CUSTOMER_ID = C.CUSTOMER_ID
LEFT JOIN (SELECT SCB.SYMBOLS_ID, COUNT(DISTINCT SCB.CONTRACT_ID) AS BPR_INS_LIFE_CNT, SUM(SCB.AMOUNT) AS FIN_INS_LIFE_BAL
FROM SCHEMA.CRM_RL_SUBSIDIARY_COMPANIE_BAT SCB
WHERE SCB.SOURCE_TCH = 'BIZTOSITO'
AND SCB.EFFECTIVE_LOAD_DATE = &GLOBAL_P_EFFECTIVE_LOAD_DATE
GROUP BY SCB.SYMBOLS_ID) LIFE_INSUR
ON LIFE_INSUR.SYMBOLS_ID = C.SYMBOLS_CUSTOMER_SID

LEFT JOIN (SELECT PD.CUSTOMER_ID, MAX(PD.DAYS_PAST_DUE) AS EXP_CRED_DAYS_MAX, ROUND(SUM(PD.PAST_DUE_AMOUNT)) AS EXP_CRED_AMT_MAX

           FROM SCHEMA.CRM_PAST_DUE PD

           JOIN SCHEMA.CRM_ARRANGEMENT AR
             ON AR.ARRANGEMENT_ID = PD.ARRANGEMENT_ID
            AND AR.START_OF_VALIDITY <= DATE'2020-01-01'
            AND AR.END_OF_VALIDITY > DATE'2020-01-01'
            AND AR.ARRANGEMENT_TYPE = 'LOAN'

           JOIN SCHEMA.CRM_LOAN L
             ON L.LOAN_ID = AR.LOAN_ID
            AND L.START_OF_VALIDITY <= DATE'2020-01-01'
            AND L.END_OF_VALIDITY > DATE'2020-01-01'
            AND L.LOAN_CODE1 NOT LIKE 'T%'

          WHERE 1 = 1
            AND PD.PAST_DUE_SID4 = 'FACILITY_MAX_DPD'
            AND PD.EFFECTIVE_LOAD_DATE = &GLOBAL_P_EFFECTIVE_LOAD_DATE
          GROUP BY PD.CUSTOMER_ID) EXPIRED_LOAN
ON EXPIRED_LOAN.CUSTOMER_ID = C.CUSTOMER_ID
LEFT JOIN KMR_FINANCIAL_INDEX_STAGE_06 SZCH
ON SZCH.CUSTOMER_ID = C.CUSTOMER_ID

WHERE 1 = 1
AND C.START_OF_VALIDITY <= DATE'2020-01-01'
AND C.END_OF_VALIDITY > DATE'2020-01-01'