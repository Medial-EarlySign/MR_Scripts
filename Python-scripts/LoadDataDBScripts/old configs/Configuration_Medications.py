import csvAnalyzer, xmlAnalyzer, re

class Configuration:
    def __init__(self):
        self.schema_name = 'MACCABI_RAW'
        self.tableName = 'MedicationsData'
        self.dataDir = 'C:\\Users\\Alon\\Documents\\RawData\\Maccabi'
        regFiles= re.compile('.*Medications_.*\.txt', re.IGNORECASE)
        self.filesFormatFunc = lambda f : len(regFiles.findall(f)) > 0

        #encodeFunc = lambda st : st.decode('windows-1255')
        #manipulateVal = dict()
        #manipulateVal['ans_remark'] = encodeFunc
        self.upload_bulk_size = 1000
        manipulateVal = None
        self.dataAnalyzerFunLazy = lambda f, h:  csvAnalyzer.analyzeFileLazy(f, delimiter = ',', header = h , topN = self.upload_bulk_size
                                                                             , manipulationFunc = manipulateVal , additionalConstFields =  {'file_path' : f})
