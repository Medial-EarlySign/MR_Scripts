import csvAnalyzer, xmlAnalyzer, re

class Configuration:
    def __init__(self):
        self.schema_name = 'MACCABI_RAW'
        self.tableName = 'LabsData'
        self.dataDir = 'C:\\Users\\Alon\\Documents\\RawData\\Maccabi'
        regFiles= re.compile('.*labsdata_.*\.txt', re.IGNORECASE)
        self.filesFormatFunc = lambda f : len(regFiles.findall(f)) > 0

        encodeFunc = lambda st : st.decode('windows-1255')
        manipulateVal = dict()
        manipulateVal['ans_remark'] = encodeFunc
        self.dataAnalyzerFun = lambda f:  csvAnalyzer.analyzeFile(f, delimiter = ',', manipulationFunc = manipulateVal , additionalConstFields = None)
        
