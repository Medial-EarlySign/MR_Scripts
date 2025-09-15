import psycopg2, traceback, logging

class KaggleDB:

    def __init__(self, schema_name, db ,usr, passw, host= None, maxErrorToRest = 3):
        self.__dbName = db
        self.__user = usr
        self.__pass = passw
        self.__host = host
        if (len(self.__pass) > 0):
            self.__conn = psycopg2.connect(host = self.__host, database=self.__dbName, user=self.__user, password=self.__pass)
        else:
            self.__conn = psycopg2.connect(host = self.__host, database=self.__dbName, user=self.__user)
        self.__errorCount = 0
        self.__maxError = maxErrorToRest
        self.__logger = logging.getLogger(__name__)
        self.schema_name = schema_name

    def close(self):
        if (self.__conn == None):
            raise NameError('Connection already closed')
        self.__conn.close()
        self.__conn = None

    def __handleError(self, sql=None):
        self.__logger.error(traceback.format_exc())
        traceback.print_exc()
        self.__errorCount = self.__errorCount + 1
        if (self.__errorCount >= self.__maxError):
            self.__errorCount = 0
            try:
                self.__conn.close()
            except:
                if sql <> None:
                    print 'Query Was: %s'%sql
                err = traceback.format_exc()
                self.__logger.error(err)
                print err
            if (len(self.__pass) > 0):
                self.__conn = psycopg2.connect(database=self.__dbName, user=self.__user, password=self.__pass)
            else:
                self.__conn = psycopg2.connect(database=self.__dbName, user=self.__user)
            
    def __executeSql(self, sql, hasRes = True):
        if (self.__conn == None):
            raise NameError('Connection already closed')
        res = None
        try:
            self.__cur = self.__conn.cursor()
            self.__cur.execute(sql)
            if hasRes:
                res = self.__cur.fetchall()
            else:
                self.__conn.commit()
            self.__cur.close()
        except:
            self.__handleError(sql)
        return res

    def __executeManySql(self, table_name ,sHeader, data):
        if (self.__conn == None):
            raise NameError('Connection already closed')
        try:
            self.__cur = self.__conn.cursor()
            self.__cur.executemany("""insert into %s.%s values(%s)
                                ;"""%( self.schema_name ,table_name ,sHeader),
                               data)
            self.__conn.commit()
            self.__cur.close()
            return True
        except:
            #traceback.print_exc()
            self.__handleError('insert into %s.%s values(%s)'%(self.schema_name ,table_name ,sHeader))
            return False
        

    def checkSchema(self):
        existsSql = """ select count(*) from information_schema.schemata where schema_name = '%s' """%self.schema_name.lower()
        res = self.__executeSql(existsSql)
        return res[0][0]

    def __createTable(self, tableName, tblF):
        sqlRaw = 'SELECT '
        for kv in tblF:
            fName = kv[0].replace(' ', '_').replace('?','')
            fType = kv[1]
            if fType == 'int':
                sqlRaw = sqlRaw + '12345' + ' AS ' + fName + ' ,'
            elif fType == 'double':
                sqlRaw = sqlRaw + '12345.01' + ' AS ' + fName + ' ,'
            elif fType == 'bool':
                sqlRaw = sqlRaw + 'true' + ' AS ' + fName + ' ,'
            elif fType == 'string':
                sqlRaw = sqlRaw + "'" + 'A' * 500 + "'::text" + ' AS ' + fName + ' ,'
            else:
                raise NameError('Unrecognize Type %s'%fType)
        sqlRaw = sqlRaw[0:-1]
        sqlRaw = sqlRaw + ' WHERE 1=0'

        self.__executeSql(""" 
        CREATE TABLE %s.%s as 
        %s
        """%(self.schema_name, tableName , sqlRaw), False)
            
    def createSchema(self, tableName, dataTbl):
        existsSql = """ select count(*) from information_schema.schemata where schema_name = '%s' """%self.schema_name.lower()
        res = self.__executeSql(existsSql)
        if res[0][0] == 1:
            print 'Schema already exists!'
        else:
            print 'Creating Schema'
            self.__executeSql(""" 
            CREATE SCHEMA %s
            """%self.schema_name, False)

        cols = self.getTableFields(tableName)
        if len(cols) == 0:
            self.__createTable(tableName, dataTbl)
        else:
            print 'Table Already exists'
        
    def getTableFields(self, tbl_name): 
        fields = list()
        sql = """SELECT  column_name 
FROM information_schema.columns where table_schema = '%s'
and table_name = '%s'
order by ordinal_position
"""%(self.schema_name.lower() ,tbl_name.lower())
        rowsTemp = self.__executeSql(sql,True)
        rowsData = map(lambda row: row[0], rowsTemp)
        for r in rowsData:
                fields.append(r)
        
        return fields

    def loadData(self, table_name, data, transFunction = None, bulkSize = None):
        tblFields = self.getTableFields(table_name)
        flCnt = len(tblFields)
        sHeader = '%s,' * flCnt 
        sHeader = sHeader[0:-1]
        res = True
        if transFunction is None:
            raise NameError('Not Supported yet.. not hard to implement')
            #transFunction = lambda tblFlds, rowDict : map ( lambda h : rowDict[h] , tblFlds)
        
        if bulkSize is None:
            allRows = map(lambda x: transFunction(tblFields, x), data)
            return self.__executeManySql(table_name ,sHeader, allRows)
        else:
            startIndex = 0
            while len(data) > startIndex:
                dataBulk = data[startIndex : startIndex + bulkSize]
                allRows = map(lambda x: transFunction(tblFields, x), dataBulk)
                actionRes = self.__executeManySql(table_name ,sHeader, allRows)
                if not(actionRes):
                    res = False
                    break
                startIndex = startIndex + bulkSize
        
        return res
