
INSERT INTO KIni
          ([IniSection]
           ,[IniKeyword]
           ,[IniValue])
     VALUES
           ('SCEDrawingManagement', 'CDMDashboard',	'SCE-E&C-CDM-AU,SCE-E&C-CDM-CM,SCE-E&C-CDM-ENGINEER'),
		   ('SCEDrawingManagement', 'CDMUser',	'SCE-E&C-CDM-AU,SCE-E&C-CDM-CM'),
		   ('SCEDrawingManagement','TDStandardsUser','SCE-E&C-CDM-T&D-STND'),
		   
		   /*==============================*/
		   /* Non-Production */
		   /*
		   ('SCEDrawingManagement', 'PrintReqReducedFullEmail',	'Antoine.Ibrahim@sce.com'),
		   ('SCEDrawingManagement', 'PrintReqOrigEmail',	'Antoine.Ibrahim@sce.com')	   
		   */
		   /*==============================*/
		   
		   /*==============================*/
		   /* Production */
		   ('SCEDrawingManagement', 'PrintReqReducedFullEmail',	'CDMGO3@SCE.com'),
		   ('SCEDrawingManagement', 'PrintReqOrigEmail',	'Dwgreten@sce.com')		   
		   /*==============================*/
           
