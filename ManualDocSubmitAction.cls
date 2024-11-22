/**************************************************************************
 @Company : CloudKaptan Consultancy Services Pvt Ltd.
 @Class : ManualDocSubmitAction
 @Description: Used to Submit Manual Documents to their respective departments
 @Developer: Reet Roy
 @Created Date: 27-01-2022
 @History : 
***************************************************************************/
public without sharing class ManualDocSubmitAction implements PortalActionAdapter{
    String appId, attachmentList;
    List<String> paramKeys;
    Map<String,Object> fields ;
    clcommon.Response res ;
    Map<String,String> docToBeSent ;
    Map<Id, clcommon__Category_Attachment_Association__c> attIdAssociationMap ;
    Map<String, String> attIdAssDocCatId ;
    Boolean typeNotFound;
    Boolean doUnderwriting;
    /* Initialising parameter keys and response */
    public ManualDocSubmitAction(){
        res = new clcommon.Response();
        docToBeSent=new map<String,String>();
        fields= new Map<String,Object>();
        paramKeys = new List<String>();
        attIdAssociationMap = new Map<Id, clcommon__Category_Attachment_Association__c>();
        attIdAssDocCatId = new Map<String, String>();
        paramKeys.add(ManualDocActionConstants.APPLICATIONID);
        paramKeys.add(ManualDocActionConstants.ATTCH_LIST);
        typeNotFound = false;
    }
    /* Setting the value of parameters incoming via POJO */
    public void setParams(Map<String,Object> param){
        try{
            Map<String,Object> customParam = new Map<String,Object>();
            /* if parameter map comes blank then exception */
            if(param!=null && !param.isEmpty()){
                for(String paramKey : paramKeys){
                    /* if parameter doesn't contain a paramKey or has null as its value */
                    if(!param.containsKey(paramKey)){
                        throw new CustomException(ManualDocActionConstants.PARAM_MISSING_EX+paramKey);
                    }else if( param.get(paramKey) == null){
                        throw new CustomException(ManualDocActionConstants.PARAM_VAL_MISSING_EX+paramKey);
                    }else{
                        String filteredVal = String.valueOf(param.get(paramKey));
                        customParam.put(paramKey,filteredVal.trim());
                    }
                }
                if(customParam != null && customParam.size() > 0 && customParam.get(paramKeys[0]) != null){
                    appId = String.valueOf(customParam.get(paramKeys[0]));
                }
                if(customParam != null && customParam.size() > 0 && customParam.get(paramKeys[1]) != null){
                    attachmentList = String.valueOf(customParam.get(paramKeys[1]));
                }

            }else{
                throw new CustomException(ManualDocActionConstants.PARAM_MAP_BLANK_EX);
            }
        }catch(Exception e){
            /* if custom exception thrown return success response with error message */
            if(e.getTypeName() == ManualDocActionConstants.CUSTOMEXCEPTIONTYPE){
                res = FlowfiUtil.getErrorMessageResponse(e.getMessage());
            }else{
                res = FlowfiUtil.getErrorResponse(ManualDocActionConstants.SOMETHING_WENT_WRONG_EX);
            }
        }
    }
    /* processing of info extracted from req json */
    public void execute(){
        try{    
            List<cls_attachments> attch;
            List<genesis__applications__c> appList=[SELECT id,
                                                            name,
                                                            Manual_Doc_Upload_Failed_Reason__c,
                                                            Broker_Application__c,
                                                            Illion_Reference_Id__c,
                                                            genesis__Account__c,
                                                            Bank_Document_Uploaded__c,
                                                            genesis__Status__c,
                                                            Portal_Page__c,
                                                            Underwriting_Initiated__c,
                                                            Application_Detail_Submition_Date__c,
                                                            Application_Submission_DateTimeStamp__c
                                                        FROM genesis__applications__c
                                                        WHERE id=:appId];
            if(appList == null || applist.size() == 0){
                throw new CustomException(ManualDocActionConstants.APP_NOT_FOUND_EX);
            }
            Id currentUserId = UserInfo.getUserId();
            if(String.isNotBlank(currentUserId) && FlowfiUtil.borrowerUserCheck()){
                        // Admin User Assignment to Document category for Borrower
                List<clcommon__document_category__c> docCatList=[SELECT id,
                                                                        ownerId,
                                                                        clcommon__Category_Name__c
                                                                        FROM clcommon__document_category__c
                                                                        WHERE genesis__Application__c=:appId
                                                                        AND clcommon__Category_Name__c=:ManualDocActionConstants.MANUAL_DOC
                                                                        LIMIT 1];
                User admId = [SELECT Id 
                                    FROM User 
                                    WHERE IsActive=true 
                                    AND Profile.Name = :ManualDocActionConstants.SYS_ADMIN 
                                    LIMIT 1];
                docCatList[0].ownerId = admId.Id;
                map<String,String> attchTypeMap=new map<String,String>();
                if(String.isNotBlank(attachmentList)){
                    attch=(List<cls_attachments>)JSON.deserialize(attachmentList,List<cls_attachments>.class);
                }
                for(cls_attachments attachType:attch){
                    attchTypeMap.put(attachType.attachmentId,attachType.docCat);
                }
                List<clcommon__Category_Attachment_Association__c> docCatAs=[SELECT id,
                                                                                    clcommon__Content_Document_Id__c,
                                                                                    Document_Submitted__c,
                                                                                    Illion_Response_Message__c,
                                                                                    Illion_Status__c,
                                                                                    Type__c,
                                                                                    Status__c,
                                                                                    clcommon__Attachment_Id__c
                                                                                FROM clcommon__Category_Attachment_Association__c 
                                                                                WHERE clcommon__Document_Category__c = :docCatList[0].Id
                                                                                AND (clcommon__Content_Document_Id__c IN:attchTypeMap.keySet()
                                                                                OR clcommon__Attachment_Id__c IN:attchTypeMap.keySet())];
                /**
                * @description : Commented code 120, 124-126, 140-148 changes LMB-1290. Code might get reverted back that's why not removed.
                * @author Rahul Mahato | 09-08-2023 
                **/   

                //List<clcommon__Category_Attachment_Association__c> bankDocCat = new List<clcommon__Category_Attachment_Association__c>();
                for(clcommon__Category_Attachment_Association__c attchAsso:docCatAs){
                    attIdAssociationMap.put(attchAsso.clcommon__Content_Document_Id__c,attchAsso);
                    attIdAssDocCatId.put(attchAsso.clcommon__Attachment_Id__c,attchAsso.clcommon__Content_Document_Id__c);
                    /*if( attchAsso.Type__c == ManualDocActionConstants.BANK_STATEMNT || attchAsso.Type__c == ManualDocActionConstants.TRX_LIST || attchAsso.Type__c == ManualDocActionConstants.INCOME_STATEMENT || attchAsso.Type__c == ManualDocActionConstants.LEASE_AGREEMENT || attchAsso.Type__c == ManualDocActionConstants.OTHER){
                        bankDocCat.add(attchAsso);
                    }*/
                    if(attchTypeMap.get(attchAsso.clcommon__Content_Document_Id__c)!=null || attchTypeMap.get(attchAsso.clcommon__Attachment_Id__c)!=null){
                        if(attchTypeMap.containsKey(attchAsso.clcommon__Content_Document_Id__c)){
                            attchAsso.Type__c=attchTypeMap.get(attchAsso.clcommon__Content_Document_Id__c);
                        }else if(attchTypeMap.containsKey(attchAsso.clcommon__Attachment_Id__c)){
                            attchAsso.Type__c=attchTypeMap.get(attchAsso.clcommon__Attachment_Id__c);
                        }
                        if(System.label.Document_Types_For_Manual_Review.split(ManualDocActionConstants.DOC_SEPARATOR).contains(attchAsso.Type__c)){
                            attchAsso.Status__c=System.label.AttachmentStatusToManualReview;
                        }
                    }else{
                        typeNotFound=true;
                    }
                }
                /*if(bankDocCat.size()==0 && Test.isRunningTest()==false){
                    if(docCatList.size() > 0){
                        update docCatList[0];
                    }
                    fields.put(ManualDocActionConstants.NO_BNK_STATEMNT,true);
                    fields.put(ManualDocActionConstants.PAGE,appList[0].genesis__Status__c);
                    res = FlowfiUtil.getSuccessResponse(ManualDocActionConstants.SUCCESS,fields); 
                    return ;
                }*/
                if(typeNotFound){  
                    throw new CustomException(ManualDocActionConstants.INVALID_DOC_TYPE);
                } else {
                    List<String> docToBeSentToMogoOcr=System.label.Document_Types_For_Mogo_OCR.split(ManualDocActionConstants.DOC_SEPARATOR);
                    List<String> docToBeSentToPWC=System.label.Document_Types_For_PWC_Protect.split(ManualDocActionConstants.DOC_SEPARATOR);
                    List<String> docToBeReviewdManually=System.label.Document_Types_For_Manual_Review.split(ManualDocActionConstants.DOC_SEPARATOR);
                    List<id> attchIdForPWC=new List<id>();
                    List<Id> attchIdForOCR=new List<id>();
                    for(cls_attachments attachType:attch){
                        if(docToBeSentToMogoOcr.contains(attachType.docCat)){
                            attchIdForOCR.add(attachType.attachmentId);
                        }
                        if(docToBeSentToPWC.contains(attachType.docCat)){
                            attchIdForPWC.add(attachType.attachmentId);
                        }
                    }
                    ManualDocSubmitAction.uploadManualDocCallout(appId,attchIdForOCR);
                    if(attchIdForPWC!=null && attchIdForPWC.size()>0){
                        //PWCProtectHandler.sendSerializedJSONToFutureMethod(attchIdForPWC);
                        PWCProtectIntegrationBatch obj = new PWCProtectIntegrationBatch(appId);
                        Database.executeBatch(obj,1);
                    }
                    applist[0].Bank_Document_Uploaded__c = true;
                    applist[0].Income_Verification_Process__c=ManualDocActionConstants.MANUAL_DOC_UPLOAD;
                    genesis__applications__c appObj=new genesis__applications__c();
                    if(appList !=null && appList.size()>0){
                        appObj=appList[0];
                    }
                    if(docCatList.size() > 0){
                        update docCatList[0];
                    }
                    List<clcommon__Category_Attachment_Association__c> consolidatedList = new List< clcommon__Category_Attachment_Association__c >();
                    if(docCatAs != null){
                        for(clcommon__Category_Attachment_Association__c key : docCatAs){
                            clcommon__Category_Attachment_Association__c docSubObj =new clcommon__Category_Attachment_Association__c();
                            docSubObj.id=key.id;
                            docSubObj.Document_Submitted__c=true;
                            consolidatedList.add(docSubObj);   
                        }
                        Database.upsert(consolidatedList,true);
                    }
                    fields.put(ManualDocActionConstants.OUTCOME,ManualDocActionConstants.REFERRED);
                    List<clcommon__Category_Attachment_Association__c> attachList=[SELECT Id,
                                                                                        Name, 
                                                                                        Type__c 
                                                                                      FROM clcommon__Category_Attachment_Association__c 
                                                                                      WHERE clcommon__Document_Category__r.clcommon__Category_Name__c =: ManualDocActionConstants.MANUAL_DOC
                                                                                      AND clcommon__Document_Category__r.genesis__Application__c=:appObj.Id
                                                                                      AND Type__c!=: ManualDocActionConstants.BANK_STATEMNT];
                    List<clcommon__Party__c> partyObjList=[SELECT Id,
                                                                Name,
                                                                Income_Verification_Process__c,
                                                                Income_Verified__c,
                                                                genesis__Application__c 
                                                            FROM clcommon__Party__c 
                                                            WHERE genesis__Application__c =: appObj.Id];
                    
                    if(partyObjList == null || partyObjList.isEmpty()) {
                        throw new CustomException(ManualDocActionConstants.BORROWER_PARTY_NOTFOUND);
                    }    
                    if (!Schema.sObjectType.clcommon__Party__c.isUpdateable())
                    {
                        throw new CustomException(CpConstants.DML_ACCESS_ERROR);
                    }                                                             
                    if(attachList!= null && !attachList.isEmpty()){
                        if(partyObjList[0].Income_Verification_Process__c == ManualDocActionConstants.MANUAL_UPLOAD){
                            partyObjList[0].Income_Verification_Process__c = ConstantValues.ILLION_OCR_PICKLIST;
                        }
                        //hotfix done as per LMB - 1363, intention to put decision on underwriting start, based on status of IV completion
                        if(!partyObjList[0].Income_Verified__c){
                            partyObjList[0].Income_Verified__c = true;
                            doUnderwriting = true;
                        }else{
                            doUnderwriting = false;
                        }                       
                    
                        update partyObjList[0];
                        //hotfix done as per LMB - 1363
                        if(doUnderwriting){
                            appObj.Underwriting_Initiated__c = true;
                            appObj.Application_Detail_Submition_Date__c = appObj.Application_Detail_Submition_Date__c == null? Date.today():appObj.Application_Detail_Submition_Date__c ;
                            appObj.Application_Submission_DateTimeStamp__c = appObj.Application_Submission_DateTimeStamp__c == null? System.now():appObj.Application_Submission_DateTimeStamp__c;
                            //Reorder POI Changes - Publising event for underwriting start on document upload
                            Underwriting_Start_Event__e eventObject = new Underwriting_Start_Event__e();
                            eventObject.Application_ID__c = String.valueOf(partyObjList[0].genesis__Application__c);
                            EventBus.publish(eventObject);
                        }
                    }
                    if(appObj !=null && Schema.sObjectType.genesis__applications__c.isUpdateable()){
                        update appObj;
                    }
                }
            } else{
                throw new CustomException(ConstantValues.INVALID_USER);
            }
            res = FlowfiUtil.getSuccessResponse(ConstantValues.success,fields);
        }catch(Exception e){
            ExceptionManager.manageException(e);
            if(e.getTypeName().equals(ManualDocActionConstants.CUSTOMEXCEPTIONTYPE)){
                res=flowfiUtil.getErrorResponse(e.getMessage());
            } else {
                res=flowfiUtil.getErrorResponse(ManualDocActionConstants.SOMETHING_WENT_WRONG_EX);
            }
        }
    }
    /*****************Return response******************/
    public clcommon.Response getPortalResponse(){
        return res;
    }
    //For Parsing JSON Response From Portal
    public class cls_attachments{
        public String id;
        public String attachmentId;
        public String attachmentName;
        public String docCat;
    }
    //Future Method for Calculating scoring and credit pull if no mogo Docs are provided
    @Future(callout=true)
    public static void uploadManualDocCallout(Id appId, List<Id> attchIdForOCR){
        genesis__applications__c appObj=new genesis__applications__c();
        IllionStatementOCRResponseParser ocrResponseObj;
        appObj.Id = appId;
        try{
            List<genesis__applications__c> appList=[SELECT id,
                                                            name,
                                                            Illion_Manual_Upload_Success__c,
                                                            Manual_Doc_Upload_Failed_Reason__c,
                                                            Broker_Application__c,
                                                            Illion_Reference_Id__c,
                                                            genesis__Account__c,
                                                            Bank_Document_Uploaded__c,
                                                            genesis__Status__c,
                                                            Portal_Page__c
                                                        FROM genesis__applications__c
                                                        WHERE id=:appId
                                                        LIMIT 1];
            if(appList == null || applist.size() == 0){
                throw new CustomException(ManualDocActionConstants.APP_NOT_FOUND_EX);
            }
            if(attchIdForOCR!=null && attchIdForOCR.size()>0){
                Datetime systemDate = System.Now();
                if(appList[0].Illion_Reference_Id__c != null){
                    ocrResponseObj = IllionOCRRequestCallout.callout(attchIdForOCR,appList[0].Illion_Reference_Id__c);
                }else{
                    throw new CustomException(ManualDocActionConstants.REF_ID_MISSING);
                } 
            }
            applist[0].Illion_Manual_Upload_Success__c = true;
            update applist;
            List<clcommon__Party__c> partylist = [SELECT Id, 
                                                            Income_Verification_Process__c 
                                                            FROM clcommon__Party__c 
                                                            WHERE genesis__Application__c = :appId 
                                                            AND clcommon__Type__r.Name = :UnderwritingBatchJobConstants.BORROWER
                                                            LIMIT 2];
            for(clcommon__Party__c party : partylist){
                party.Income_Verification_Process__c = ManualDocActionConstants.MANUAL_DOC_UPLOAD;
            }
            update partylist;
        } catch( Exception e ){
            if(e.getTypeName() == ManualDocActionConstants.CUSTOMEXCEPTIONTYPE){
                appObj.Manual_Doc_Upload_Failed_Reason__c = e.getMessage();
            } else {
                appObj.Manual_Doc_Upload_Failed_Reason__c = ManualDocActionConstants.SOMETHING_WENT_WRONG_EX;
            }
            update appObj;
        }
    }
}
