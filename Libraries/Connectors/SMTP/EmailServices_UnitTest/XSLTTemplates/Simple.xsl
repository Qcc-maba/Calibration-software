<?xml version="1.0" encoding="iso-8859-1" ?>

<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:formatobj="urn:FormatObj">
  <xsl:param name="UserName" />
  <xsl:param name="Link" />


  <xsl:template match="/">
    <html>
      <head>

        <title>The Elegant Email Company</title>

        <meta content="text/html; charset=iso-8859-1" http-equiv="Content-Type" />
        <style type="text/css">
          .list a {
          color: #cc0000;
          text-transform: uppercase;
          font-family: Verdana;
          font-size: 11px;
          text-decoration: none;
          }
        </style>


      </head>


      <body marginheight="0" topmargin="0" marginwidth="0" bgcolor="#c5c5c5" leftmargin="0">
        <div>
          Click
          <xsl:element name="a">
            <xsl:attribute name="href">
              <xsl:value-of select="$Link"/>
            </xsl:attribute>
            <xsl:attribute name="id">
              <xsl:value-of select="$UserName"/>
            </xsl:attribute>
            here
          </xsl:element>
        </div>
        
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>



