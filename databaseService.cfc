<cfcomponent output="false" displayname="database Service"   hint="Service layer that abstracts Crud functions into a single or several function call(s) for the default CFC's (or prototype CFM templates) created by Illudium CFC Generator or CF Simple" >
<!--- Document Information -----------------------------------------------------

Title:       databaseService.cfc

Author:      gerald.guido
Email:       gerald.guido@gmail.com
 
Website:     www.myinternetisbroken.com

Purpose:    Abstracts Crud functions into one function call used in conjunction with the default CFC's (prototype CFM template) created by Illudium CFC Generator or CF Simple

Usage:		

runmethod():
 
Get_myTable = application.databaseservice.runmethod(myAction, myTable, myStruct [, orderBy, reloadObjects, myDsn, myCfcPath])
 
takes three to seven args:
myAction: Action to run- Upsert (insert/update) and Delete (DELETE)

Note on Upsert: If the ID is zero (0) or if the ID does not exist it will insert a new record other wise it will update the record of the supplied ID

myTable:  Table to modify

myStruct: Structure Holding the values to modify . Could be any of CF's
			native structures: Form, URL, session, Application etc. or a
			user defined struct


orderBy: The order by clause for a select statement 
reloadObjects: Reloads the CFCs into the application scope

----------------
GetMaxID: Gets the ID of the last insert - Note: use with cflock
myDsn =  The DSN to use for the loadObjects function 
myCfcPath =  The base path to the CFCs used for the loadObjects function 



myID = application.databaseservice.GetMaxID(myTable, myPK, myDsn);

------------
Each Database Table has The following CFCs
	bean  		to encapsilate a data set
	Gateway 	for retrieving data (select)
	DAO 		For manipulating (insert update DELETE etc)

The application.databaseservice.runmethod method is used to access the database for simple CRUD opperations.
Each opperation requires that you pass the function a structure (EX: Form, URL or a custom Struct).

If a struct key name(i.e. key/value pair) matches a field in the database the database CFCs will use the value for updating or retriving data

So if you pass a form (a structure) to the runmethod function that contains form.ID and Form.Fname and there are collumns in the named ID and Fname
The form values will be used in the query. Any vars in a strct that do not match will be ignored (Ex: form.action)

EX:
index.cfm?tbl_Trip_Code=3&fname=fred
<cfset get_Trip_Code  = Application.databaseService.runmethod("select","tbl_Trip_Code", URL)>

If any of the URL variables match any of the column names those values will be used to filter the results

The above URL will return a query contain all rows in the tbl_Trip_Code table that have an ID of 3 and a fname of "fred".


Changes 
23/05/2009	
Got sick of regenerating ALL of the objects when a single change was made, so a lazy load feature with a manual over ride (reloadObjects argument) was added.
RunMethod now checks to see if the bean, Gateway and DAO are all loaded and if not, it instantiates it and loads them into the Application Scope.

This bypasses having to create the loadObjects.cfm script or use ColdSpring to load objects into memory. 
This will reduce initial load time when an application is first started. On CF 7 this can be substantal if there are a lot (50+) of tables

07/16/2009
Added saveManyToMany() to save Many To Many items. This was inspired and modeled after Steve Bryants excellect DataMgr library. 
I basicall rewrote one  of his functions to work with my functions, 
http://datamgr.riaforge.org/
http://www.bryantwebconsulting.com/cfcs/

07/17/2009
Abstracted all the database methods out of runmethod() and into their own functions. And after looking at 
the ORM in CF 9 I decided that it would be nice to be able to run these methods outside of runmethod().

Modification Log:

Name			Date			Description
================================================================================
Coz		04/03/2009		Created
Coz		05/23/2009		rewrote Lazyload option added
Coz		05/23/2009		loadObjects function added for lazy load
Coz		07/16/2009		Added saveManyToMany() to save Many To Many items.
Coz		07/17/2009		Abstracted all the database methods out of runmethod() and into their own functions
Coz		07/17/2009		Added checkAndLoadObjects() so the individual database methods can be run individually
Coz		07/20/2009		Abstracted bean creation  to it's own function i.e. getBean()
------------------------------------------------------------------------------->


	<cffunction name="init">
		<cfreturn  this>
	</cffunction>

	<cffunction name="runMethod" access="public" output="false" returntype="Any" hint="I act as a front end for the cf_query custom tag or as a stand alone function. I perform the following actions: select|save|Upsert|insert|update|Delete">
		<cfargument name="myAction" type="String" required="true"  default=""  hint="I perform the following actions: select|save|Upsert|insert|update|Delete"/>
		<cfargument name="myTable" type="String" required="true" hint="The table to use"/>
		<cfargument name="myStruct" type="struct" required="true" hint="Structure holding the values used to update the database"/>
		<cfargument name="orderBy" type="string" required="false" default="" hint="Values to use in the orderBy statement sans ORDER BY"/>
		<cfargument name="reloadObjects" type="string" required="false" default="false" hint="Manual over ride. This will reload the objects even if they are loaded"	 />
		<cfargument name="myDsn" type="string" required="false" default="#application.dsn#" hint="The DSN - Defaults to Application.DSN"/>
		<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#" hint="The Dot.Notation.Path to the CFC directory"/>
		<cfset var myQ = "" />

		<cfset var reload = "false" />
 
		<cfif NOT structkeyexists(arguments.myStruct, "orderBy")>
			<cfif arguments.myAction EQ "select">
				<cfif Trim(arguments.orderBy) NEQ "">
					<cfset  structinsert(arguments.myStruct, "orderBy", arguments.orderBy, "false")>
				</cfif>
			</cfif>
		</cfif>
		   
		<cfset checkAndLoadObjects(arguments.myTable, arguments.myDsn, arguments.myCfcPath,arguments.reloadObjects)>
		 

		<cfif arguments.myAction EQ "delete">
 			<cfset myQ = delete(arguments.myTable,arguments.myStruct) />
		<cfelseif arguments.myAction EQ "select"> 
		 	<cfset myQ = select(arguments.myTable,arguments.myStruct) /> 
		<cfelseif arguments.myAction EQ "update">
		 	<cfset myQ = update(arguments.myTable,arguments.myStruct) />  
		<cfelseif arguments.myAction EQ "insert">
			 <cfset myQ = insertinto(arguments.myTable,arguments.myStruct) /> 
		 
		<cfelseif arguments.myAction EQ "Upsert" OR  arguments.myAction EQ "save">
			<cfset myQ = upsert(arguments.myTable,arguments.myStruct) /> 
		</cfif>
		
		 <cfreturn   myQ  /> 
	</cffunction>

 
	<cffunction name="delete" access="public" output="false" returntype="Any" hint="I Delete a record from the database">
	 	<cfargument name="myTable" type="String" required="true" hint="The table to use"/>
	 	<cfargument name="myStruct" type="struct" required="true" hint="Structure holding the values used to update the database"/>
 		<cfargument name="reloadObjects" type="string" required="false" default="false" hint="Manual over ride. This will reload the objects even if they are loaded"	 />
		<cfargument name="myDsn" type="string" required="false" default="#application.dsn#" hint="The DSN - Defaults to Application.DSN"/>
		<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#" hint="The Dot.Notation.Path to the CFC directory"/>
	 	<cfset var myQ = ""> 
	 	<cfset var tmp = checkAndLoadObjects(arguments.myTable, arguments.myDsn, arguments.myCfcPath,arguments.reloadObjects)> 
			<cfinvoke 	component="#application[arguments.myTable & "DAO"]#" 
						method="delete" 
						returnvariable="myQ">  
						<cfinvokeargument name="#arguments.myTable#" value="#getBean(arguments.myTable,arguments.myStruct)#"/>
			</cfinvoke>
		
  		<cfreturn myQ> 
	</cffunction>
 

	<cffunction name="select" access="public" output="false" returntype="query" hint="I Delete a record from the database">
	 	<cfargument name="myTable" type="String" required="true" hint="The table to use"/>
	 	<cfargument name="myStruct" type="struct" required="true" hint="Structure holding the values used to update the database"/>
	 	<cfargument name="orderBy" type="string" required="false" default="" hint="The ordery by in the SQL (sans the ORDER BY)" />
  		<cfargument name="reloadObjects" type="string" required="false" default="false" hint="Manual over ride. This will reload the objects even if they are loaded"	 />
		<cfargument name="myDsn" type="string" required="false" default="#application.dsn#" hint="The DSN - Defaults to Application.DSN"/>
		<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#" hint="The Dot.Notation.Path to the CFC directory"/>
	 	<cfset var myQ = ""> 
		<cfset var tmp = checkAndLoadObjects(arguments.myTable, arguments.myDsn, arguments.myCfcPath,arguments.reloadObjects)>
		
			<cfif NOT structkeyexists(arguments.myStruct, "orderBy")> 
				<cfif Trim(arguments.orderBy) NEQ "">
					<cfset  structinsert(arguments.myStruct, "orderBy", arguments.orderBy, "false")>
				</cfif> 
			</cfif>
		
			<cfinvoke 	component="#application["#arguments.myTable#Gateway"]#" 
						method="getByAttributesQuery" 
						returnvariable="myQ" 
						argumentcollection="#arguments.myStruct#" /> 
		 
  		<cfreturn myQ> 
	</cffunction>


	<cffunction name="update" access="public" output="false" returntype="Any" hint="I update a record from the database">
	 	<cfargument name="myTable" type="String" required="true"hint="The table to use" />
	 	<cfargument name="myStruct" type="struct" required="true" hint="Structure holding the values used to update the database"/>
   		<cfargument name="reloadObjects" type="string" required="false" default="false" hint="Manual over ride. This will reload the objects even if they are loaded"	 />
		<cfargument name="myDsn" type="string" required="false" default="#application.dsn#" hint="The DSN - Defaults to Application.DSN"/>
		<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#" hint="The Dot.Notation.Path to the CFC directory"/>
	 	<cfset var myQ = "">
	 	<cfset var tmp = checkAndLoadObjects(arguments.myTable, arguments.myDsn, arguments.myCfcPath,arguments.reloadObjects)>

			<cfinvoke 	component="#application[arguments.myTable & "DAO"]#" 
						method="update" 
						returnvariable="myQ" >
					 		<cfinvokeargument name="#arguments.myTable#" value="#getBean(arguments.myTable,arguments.myStruct)#"/>
			</cfinvoke>
		
  		<cfreturn myQ> 
	</cffunction>

		<!--- insert is a built in CF functiom --->
	<cffunction name="insertInto" access="public" output="false" returntype="Any" hint="I update a record from the database - insert is a built in CF functiom hence the name">
	 	<cfargument name="myTable" type="String" required="true" hint="The table to use"/>
	 	<cfargument name="myStruct" type="struct" required="true" hint="Structure holding the values used to update the database"/>
  		<cfargument name="reloadObjects" type="string" required="false" default="false"  hint="Manual over ride. This will reload the objects even if they are loaded"	 />
		<cfargument name="myDsn" type="string" required="false" default="#application.dsn#" hint="The DSN - Defaults to Application.DSN" />
		<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#" hint="The Dot.Notation.Path to the CFC directory"/>
	 	<cfset var myQ = ""> 
	 	<cfset var tmp = checkAndLoadObjects(arguments.myTable, arguments.myDsn, arguments.myCfcPath,arguments.reloadObjects)>
  
			<cfinvoke 	component="#application[arguments.myTable & "DAO"]#" 
						method="create" 
						returnvariable="myQ" >
					 		<cfinvokeargument name="#arguments.myTable#" value="#getBean(arguments.myTable,arguments.myStruct)#"/>
			</cfinvoke>
		
  		<cfreturn myQ> 
	</cffunction>
 
 	<cffunction name="upsert" access="public" output="false" returntype="Any" hint="I update a record from the database">
	 	<cfargument name="myTable" type="String" required="true" hint="The table to use"/>
	 	<cfargument name="myStruct" type="struct" required="true" hint="Structure holding the values used to update the database"/>
  		<cfargument name="reloadObjects" type="string" required="false" default="false" hint="Manual over ride. This will reload the objects even if they are loaded"	 />
		<cfargument name="myDsn" type="string" required="false" default="#application.dsn#" hint="The DSN - Defaults to Application.DSN"/>
		<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#" hint="The Dot.Notation.Path to the CFC directory"/>
	 	<cfset var myQ = "">
	 	<cfset var tmp = checkAndLoadObjects(arguments.myTable, arguments.myDsn, arguments.myCfcPath,arguments.reloadObjects)>
  
			<cfinvoke 	component="#application[arguments.myTable & "DAO"]#"
						method="save" 
						returnvariable="myQ" >
					 		<cfinvokeargument name="#arguments.myTable#" value="#getBean(arguments.myTable,arguments.myStruct)#"/> 
			</cfinvoke>
		
  		<cfreturn myQ> 
	</cffunction>

 	<cffunction name="save" access="public" output="false" returntype="Any" hint="I update a record from the database">
	 	<cfargument name="myTable" type="String" required="true" hint="The table to use"/>
	 	<cfargument name="myStruct" type="struct" required="true" hint="Structure holding the values used to update the database"/>
  		<cfargument name="reloadObjects" type="string" required="false" default="false"  hint="Manual over ride. This will reload the objects even if they are loaded"	 />
		<cfargument name="myDsn" type="string" required="false" default="#application.dsn#" hint="The DSN - Defaults to Application.DSN"/>
		<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#" hint="The Dot.Notation.Path to the CFC directory"/>
	 	<cfset var myQ = "">
	 	<cfset var tmp = checkAndLoadObjects(arguments.myTable, arguments.myDsn, arguments.myCfcPath,arguments.reloadObjects)>
 
			<cfinvoke 	component="#application[arguments.myTable & "DAO"]#"
						method="save" 
						returnvariable="myQ" >
						 	<cfinvokeargument name="#arguments.myTable#" value="#getBean(arguments.myTable,arguments.myStruct)#"/> 
			</cfinvoke>
		
  		<cfreturn myQ> 
	</cffunction>
   
	<cffunction name="saveManyToMany" access="public" returntype="String" output="false" hint="I save a many-to-many relationship.">
		<cfargument name="myTable" type="string" required="yes" hint="The table holding the many-to-many relationships.">
		<cfargument name="myFK" type="string" required="yes" hint="The field holding our key value for relationships.">
		<cfargument name="myFKvalue" type="string" required="yes" hint="The value of out primary field.">
		<cfargument name="manyfield" type="string" required="yes" hint="The field holding our many relationships for the given key.">
		<cfargument name="manyValueList" type="string" required="yes" hint="The list of related values for our key.">
		<cfargument name="reloadObjects" type="string" required="false" default="false" hint="Manual over ride. This will reload the objects even if they are loaded" />
		<cfargument name="myDsn" type="string" required="false" default="#application.dsn#" hint="The DSN - Defaults to Application.DSN"/> />
		<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#"  hint="The Dot.Notation.Path to the CFC directory"/>
	 	
		<cfset var getStruct = StructNew()>
		<cfset var setStruct = StructNew()>
		<cfset var qExistingRecords = 0>
		<cfset var item = "">
		<cfset var ExistingList = "">
			 <!--- Check whether Objects are loaded --->
	  
		<cfset var tmp = checkAndLoadObjects(arguments.myTable, arguments.myDsn, arguments.myCfcPath,arguments.reloadObjects)>
		  
		<!--- Make sure a value is passed in for the primary key value --->
		<cfif NOT Len(Trim(arguments.myFK))>
			<cfthrow message="You must pass in a value for myFK of saveManyToMany" type="databaseService" errorcode="NoFKForsaveManyToMany">
		</cfif>
		 
		<!--- Get existing records --->
		<cfset getStruct[arguments.myFK] = arguments.myFKvalue>
	<!--- 	<cfset qExistingRecords = getRecords(arguments.myTable,getStruct)> --->
		
		 <cfinvoke 	component="#this#" 
					method="select" 
					returnvariable="qExistingRecords"> 
						<cfinvokeargument name="myTable" value="#Arguments.myTable#"/>
						<cfinvokeargument name="myStruct" value="#getStruct#"/> 
						<cfinvokeargument name="myDsn" value="#Arguments.myDsn#"/>
						<cfinvokeargument name="myCfcPath" value="#Arguments.myCfcPath#"/>
			</cfinvoke>
	<!--- 	<cfdump var="#qExistingRecords#"> --->
		 
		<!--- Remove existing records not in list --->
		<cfoutput query="qExistingRecords">
			<cfset ExistingList = ListAppend(ExistingList,qExistingRecords[arguments.manyfield][CurrentRow])>
			
			<cfif NOT ListFindNoCase(arguments.manyValueList,qExistingRecords[arguments.manyfield][CurrentRow])>
				 
				<cfset setStruct = StructNew()>
				<cfset setStruct[arguments.myFK] = arguments.myFKvalue>
				<cfset setStruct[arguments.manyfield] = qExistingRecords[arguments.manyfield][CurrentRow]>  
				
				 <cfquery name="qDelete" datasource="#Arguments.myDsn#">
					DELETE 	FROM	#Arguments.myTable# 
					WHERE	 #arguments.myFK# = #arguments.myFKvalue#
					AND			#arguments.manyfield# = #qExistingRecords[arguments.manyfield][CurrentRow]#
				</cfquery>  
				
			</cfif>
		</cfoutput>
		<!--- <cfdump var="#setStruct#"> --->
		 
		<!--- Add records from list that don't exist --->
		<cfloop index="item" list="#arguments.manyValueList#">
			<cfif NOT ListFindNoCase(ExistingList,item)>
				<cfset setStruct = StructNew()>
				<cfset setStruct[arguments.myFK] = arguments.myFKvalue>
				<cfset setStruct[arguments.manyfield] = item>  
				<!--- <cfset myBeanObj =  application[arguments.myTable].init(argumentCollection = setStruct)  /> --->
		 		<cfset  runmethod("insert",Arguments.myTable,setStruct)>
				<cfset ExistingList = ListAppend(ExistingList,item)><!--- in case list has one item more than once (4/26/06) --->
			</cfif>
		</cfloop> 
	</cffunction>
	
 
	 <cffunction name="getBean" access="public" output="false" returntype="Any" hint="I create Bean objects from a struct">
		<cfargument name="myTable" type="String" required="true" hint="The table to check for" />
		<cfargument name="myStruct" type="struct" required="true" hint="Structure holding the values used to update the database"/>
	
		<cfset var myBeanObj =  application[arguments.myTable].init(argumentCollection = arguments.myStruct)  />
		<cfreturn myBeanObj>
	</cffunction>
	 
	 

	<cffunction name="getMaxID" access="public" output="false" returntype="Any" hint="I get the last inserted ID - Use with an insert to get the PK of an auto incremented ID">
	 	<cfargument name="myTable" type="String" required="true"  hint="The table to use" />
		<cfargument name="myPK" type="String" required="true" default="0" hint="The primary Key" />
		<cfargument name="myDsn" type="String" required="true" default="#Application.DSN#" hint="The DSN - Defaults toApplication.DSN " />
		
		<cfquery name="Get_Max_ID"  datasource="#arguments.myDsn#" >
			SELECT MAX(#arguments.myPK#) AS		MAX_PK
			FROM #arguments.myTable#
		</cfquery>

		 <cfreturn  Get_Max_ID.MAX_PK  />
	</cffunction>
 


	 <cffunction name="checkAndLoadObjects" access="public" output="false" returntype="void" hint="I check to see of the objects exist in memory and if not I load them into the Application Scope">
		<cfargument name="myTable" type="String" required="true" hint="The table to check for" />
		<cfargument name="myDsn" type="string" required="false" default="#application.dsn#" hint="The DSN" />
		<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#" hint="The Dot.Notation.Path to the CFC directory" />
		<cfargument name="reloadObjects" type="String" required="false" default="false" hint="Manual over ride. This will reload the objects even if they are loaded" />	 
		 
			<cfif checkObjects(arguments.myTable) OR  arguments.reloadObjects EQ "true"> 
				 <cfset loadObjects(arguments.myTable, arguments.myDsn, arguments.myCfcPath)>
			</cfif>   
	</cffunction>

	<cffunction name="checkObjects" access="public" output="false" returntype="string" hint="I check to see of the object exist in the Application Scope">

		<cfargument name="myTable" type="String" required="true" />
		
		<cfset var reload = "false" />
		<cfset var tmpmyObj = "#arguments.myTable#">
		<cfset var tmpmygatewayObj = "#arguments.myTable#Gateway">
	 	<cfset var tmpmyDAOObj = "#arguments.myTable#DAO">
 

	 	<cfif  	(	NOT isdefined("Application.#arguments.myTable#")
	 			OR  NOT isdefined("Application.#arguments.myTable#Gateway")
	 			OR  NOT isdefined("Application.#arguments.myTable#DAO")
	 			) >
				 
			<cfset reload = "true"> 
		<cfelse> 
		
			<cfif  	NOT isObject(Application[tmpmyObj]) 
					OR NOT isObject(Application[tmpmygatewayObj]) 
				 	OR NOT isObject(Application[tmpmyDAOObj])>
					
				<cfset reload = "true"> 
				
			</cfif> 
			
		</cfif>
		<cfreturn reload >
 	</cffunction>



	<cffunction name="loadObjects" access="public" output="false" returntype="Any" hint="I load the database objects into memory">
	 	<cfargument name="myTable" type="String" required="true" hint="The table to use"  />
	 	<cfargument name="myDsn" type="String" required="true"  hint="The DSN - Defaults to Application.DSN"/>
	 	<cfargument name="myCfcPath" type="String" required="false" default="#Application.myCfcPath#"  hint="The Dot.Notation.Path to the CFC directory" />
	 	<cfset var mydoa = "">
	 	<cfset var myGateway = "">
	 	<cfset var myCfcDotPath = "#arguments.myCfcPath##arguments.myTable#">

		<cfscript>
			"Application.#arguments.myTable#" = CreateObject("component", "#myCfcDotPath#").init();
			"Application.#arguments.myTable#DAO" = CreateObject("component", "#myCfcDotPath#DAO").init(arguments.myDsn);
			"Application.#arguments.myTable#Gateway" = CreateObject("component", "#myCfcDotPath#Gateway").init(arguments.myDsn);
			 
		</cfscript>

	</cffunction>
	
	

	

</cfcomponent>
