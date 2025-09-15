import csvAnalyzer, xmlAnalyzer

class Configuration:
    def __init__(self):
        self.schema_name = 'MACCABI_RAW'
        self.tableName = 'Bmi'
        self.dataDir = 'C:\\Users\\Alon\\Documents\\RawData\\Maccabi'
        self.filesFormatFunc = lambda f : f.endswith('BMI.txt')

        self.dataAnalyzerFun = lambda f:  csvAnalyzer.analyzeFile(f, delimiter = ',', manipulationFunc = None , additionalConstFields = None)
        
