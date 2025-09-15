from xml.dom import minidom
import os

def parseXml(fPath):
    fid = open(fPath)
    strText = fid.read().replace('&', '&amp;').strip()
    fid.close()
    if len(strText) == 0:
        return None, None
    #xmldoc = minidom.parse(fPath)
    xmldoc = minidom.parseString(strText)
    postlist = xmldoc.getElementsByTagName('post')
    posts = list()
    for post in postlist:
        postData = dict()
        postData['post_id'] = post.getAttribute('id')
        postData['file_name'] = os.path.basename(fPath).replace('.xml','')
        for col in post.childNodes:
            colName = col.localName
            if colName == None or len(colName) == 0:
                continue
            if len(col.childNodes) ==0:
                postData[colName] = ''
                continue
            if colName == 'user':
                postData['user_id'] = col.getAttribute('id')
                for c in col.childNodes:
                    colName = c.localName
                    if colName == None or len(colName) == 0:
                        continue
                    if len(c.childNodes) > 1:
                        print c.toprettyxml()
                        raise NameError('format Error in user')
                    if len(c.childNodes) ==0:
                        postData[colName] = ''
                        continue
                
                    colVal = c.childNodes[0].data
                    postData[colName] = colVal
                continue
                    
            if len(col.childNodes) <> 1:
                print col.toprettyxml()
                raise NameError('format Error')
            try:
                colVal = col.childNodes[0].data
            except:
                print col.childNodes[0].toprettyxml()
                raise
            postData[colName] = colVal
        posts.append(postData)
    return posts, posts[0].keys()
        
