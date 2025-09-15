import csvAnalyzer, xmlAnalyzer, medialAnalyzer, re

class Configuration:
    def __init__(self):
        # 1. Target
        self.host = '192.168.102.41'
        self.db_name = 'postgres'
        self.user_name = 'postgres'
        self.password = ''
        self.schema_name = 'postgres' 
        self.tableName = 'Glucose' # Target Table name, will create it from data source files columns if not exists
        
        # 2. Source
        self.dataDir = '/nas1/Temp/Thin_2018_Loading/FinalSignals' # folder with files to upload to db - search recursive in this folder for
        # files that return true for self.filesFormatFunc condition. it can load multipal files to same table. when it fails
        # next time it starts, its skips the already success files uploaded
        self.filesFormatFunc = lambda f : re.match('.*/Glucose$', f) is not None # files filter to upload from dataDir table
        
        # 3. Other Tunings and configurations of data parsing and manipulations:
        self.upload_bulk_size = 10000 # Bulk size for uploading to DB, we can use the same number also for reading file
        # Put None to cancel bulking and load all the file as 1 bulk
        self.header = [ 'pid', 'time', 'value' ]
        tokens_select = lambda tokens: [tokens[0], tokens[2], tokens[3]]
        self.dataAnalyzerFunLazy = lambda f, h:  csvAnalyzer.analyzeFileLazy(f, header = self.header, #pass header if files doesn't contain header
                                                                  delimiter = '\t', #delimeter fot csv
                                                                  manipulationFunc = None, #dictionary for functions to manipulate fields in the csv. example 1
                                                                  additionalConstFields = None, #additionalFields to add fields for table. see example 2
                                                                  topN = self.upload_bulk_size, # file reading bulk size
                                                                  select_tokens_fun = tokens_select)  # manipluation to tokens in each line
        
        
        
        # Example 1: manipulation function for fields:
        # manipulationFunc = dict()
        # manipulationFunc['field_name_in_csv'] = lambda field_value : field_value * 100
        # this manipulation function change the field "field_name_in_csv" and multiply it by 100
        # you can provide more manipulations to other fields
        
        # Example 2: adding additional field with the full path to the file name:
        # self.dataAnalyzerFunLazy = lambda f, h:  csvAnalyzer.analyzeFile(f, header = h, delimiter = ',' ,
        #                                                                 topN = self.upload_bulk_size,
        #                                                                additionalConstFields = { 'file_path' : f } )
        # This will add an additional field named "file_path" with full path of the uploaded data file
        
        #run this program with python LoadDataManager.py
