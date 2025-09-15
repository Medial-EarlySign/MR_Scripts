import os, socket, traceback
import time, logging
from datetime import datetime
from KaggleDB import KaggleDB
import csvAnalyzer
from Configuration import *

class DataLoader:
    def __init__(self):
        self.cfg = Configuration()
        self.__initLogging()
        self.__db = None
        self.__dataH = None
        
    def __initLogging(self):
        if not(os.path.exists('log')):
            os.makedirs('log')
        serverName = socket.gethostname()
        logfmt = '%(asctime)s\t' + serverName + '\t%(levelname)s\t%(name)s\t%(threadName)s\t%(message)s'
        datef = '%d-%m-%Y %H:%M:%S'
        fname = os.path.join('log', '%s.log'%time.strftime('%d-%m-%Y', time.localtime()))
        logging.basicConfig(level=logging.INFO, format=logfmt, datefmt=datef, filename=fname)
        
    def __logFile(self, fpath):
        f = open('insert.log', 'a')
        f.write('%s\n'%fpath)
        f.close()
        
    def __getAllDone(self):
        if not(os.path.exists('insert.log')):
            return []
        f = open('insert.log', 'r')
        data = f.readlines()
        f.close()
        data = map(lambda line: line.strip(), data)
        return data

    def __tryDouble(self, raw):
        try:
            float(raw)
            return True
        except:
            return False

    def __convertToType(self, rawData, fieldType, header):
        res = None
        #print 'Format Error, Got "%s" to type "%s" of header "%s"'%(rawData, fieldType, header)
        #raise NameError('Quit')
        try:
            if fieldType == 'double':
                if rawData==None or len(rawData) == 0:
                    res = None
                else:
                    res = float(rawData)
            elif fieldType == 'int':
                if rawData==None or len(rawData) == 0:
                    res = None
                else:
                    res = int(rawData)
            elif fieldType == 'bool':
                if rawData==None or len(rawData) == 0:
                    res = None
                else:
                    res= bool(rawData)
            elif fieldType == 'string':
                if type(rawData) == file:
                    rawData = rawData.name
                if rawData==None or len(rawData) == 0:
                    res = None
                else:
                    res = rawData
            else:
                raise NameError('unknown type %s'%fieldType)
        except:
            print 'Format Error, Got "%s" to type "%s" of header "%s"'%(rawData, fieldType, header)
            traceback.print_exc()
        
        return res

    def __prepareDataType(self, folderPath, filesFormatFunc, analyzerFun):
        if not(os.path.exists(folderPath)):
            raise NameError('Path not exist "%s"'%folderPath)
        allFiles = self.__recursiveList(folderPath)
        before_cnt= len(allFiles)
        example = ''
        if before_cnt > 0:
            example=allFiles[0]
        allFiles = filter(lambda f : filesFormatFunc(f) , allFiles)
        if len(allFiles) == 0:
            print folderPath
            if before_cnt > 0:
                print('%s'%(example))
            raise NameError('haven\'t found data files for upload out of %d'%(before_cnt))
        exampleFile = allFiles[0]
        fullPath = os.path.join(folderPath, exampleFile)
        #[data, headers] = analyzerFun(fullPath, self.cfg.csv_delimeter, self.cfg.csv_transFunc, self.cfg.csv_additionalDict)
        [tmp, fileOut] = analyzerFun(fullPath, None)
        data = fileOut[0]
        headers = fileOut[1]
        #if len(data) == 0:
        #    raise NameError('data file is empty')
        
        #headers = data[0].keys()
        tableTypes=  list()
        for h in headers:
            dataType = 'double'
            for rowDict in data:
                if not(rowDict.has_key(h)):
                    print rowDict
                    raise NameError('missing code: %s'%h)
                rawData = rowDict[h]
                if len(rawData) == 0:
                    continue
                if not(self.__tryDouble(rawData)):
                    dataType = 'string'
                    break
            tableTypes.append([h ,dataType])
        return tableTypes

    def initDB(self):
        self.__db = KaggleDB(self.cfg.schema_name, self.cfg.db_name, self.cfg.user_name, self.cfg.password, self.cfg.host)
        
        print 'Analyzing Data...'
        self.__dataH = self.__prepareDataType(self.cfg.dataDir, self.cfg.filesFormatFunc, self.cfg.dataAnalyzerFunLazy)
        
        print 'Createing Schema'
        self.__db.createSchema(self.cfg.tableName , self.__dataH)
        print 'Finished!'

    #TODO: load in parallel
    def __loadDataFile(self, fpath):
        convFunc = lambda allFields, rowDict:  map(lambda kvFieldType: self.__convertToType( rowDict[kvFieldType[0]], kvFieldType[1], kvFieldType[0] ) , self.__dataH)
        dbFunc = lambda x: self.__db.loadData(self.cfg.tableName , x, convFunc, self.cfg.upload_bulk_size)
        analyzeFun = self.cfg.dataAnalyzerFunLazy
        
        if not(os.path.exists(fpath)):
            raise NameError('Path not exist')
        allDone = self.__getAllDone()
        if allDone.count(fpath):
            print 'Already Done!'
            return
        
        headers = None
        print 'Loading File "%s"...'%os.path.basename(fpath)

        f = fpath
        start_time = datetime.now()
        last_update=start_time
        update_interval=30
        total_p = 0
        while True:
            [f, fileOut] = analyzeFun(f, headers)
            data = fileOut[0]
            headers = fileOut[1]
            if data == None:
                break
            #print 'Inserting To DB...'
            succ = dbFunc(data)
            if not(succ):
                break
            curr_time=datetime.now()
            time_passed = (curr_time-last_update).total_seconds()
            total_p += len(data)
            if time_passed >= update_interval:
                total_time=(curr_time-start_time).total_seconds()
                print('%s :: (passed %2.1f minutes) Processed %d, processing %2.1f rows in second'%(curr_time, total_time/60, total_p, total_p/total_time))
                last_update=curr_time
            
            
        if succ:
            self.__logFile(fpath)
            print 'Done!'
        else:
            print 'Error, please see logs...'

    def __recursiveList(self, fDir):
        allFiles = os.listdir(fDir)
        allFiles = map(lambda f: os.path.join(fDir, f), allFiles)
        for fullCan in allFiles:
            if os.path.isdir(fullCan):
                sonsFiles = self.__recursiveList(fullCan)
                allFiles.extend(sonsFiles)
        return allFiles

    def loadAllData(self):
        func = lambda x: self.__loadDataFile(x)
        filtF = self.cfg.filesFormatFunc
        fDir = self.cfg.dataDir
        
        if not(os.path.exists(fDir)):
            raise NameError('Path not exist')
        allFiles = self.__recursiveList(fDir)
        allFiles = filter(lambda f : filtF(f) , allFiles)
        for fil in allFiles:
            fullPath = os.path.join(fDir, fil)
            func(fullPath)

    def close(self):
        if self.__db <> None:
            self.__db.close()
            self.__db = None

if __name__ == '__main__':
    dl = DataLoader()
    dl.initDB()
    dl.loadAllData()

    dl.close()
