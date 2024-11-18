<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:FormatObj="urn:FormatObj">
  <xsl:param name="UserName" />
  <xsl:param name="Link" />
  <xsl:template match="/">
    <html>
      <head>
      </head>

      <body >
        <div>
          UserName  = <xsl:value-of select="$UserName"/>
          Function1 = <xsl:value-of select="FormatObj:Function1('Parameter1Value',2,'3')"/>:
          Main Project Name: <xsl:value-of select="FormatObj/Project/Name"/>
        </div>


        <div>

          <xsl:for-each select="FormatObj/Projects/ProjectClass">
            <!-- Sort resources alphabetically by name -->
            <xsl:sort select="Name" />
            <p>
              Project Name:<xsl:value-of select="Name"/>
              <br/>
              Project ID:<xsl:value-of select="@ID"/>

              <xsl:if test="@ID[.=2]">
                <b>
                  TWO-<xsl:value-of select="@ID"/>
                </b>
              </xsl:if>
            </p>
          </xsl:for-each>

        </div>

        <div>
          <a href="http://xxx.com/" style="clip: rect(auto, auto, auto, auto); border-style: hidden">
            <img border="0" >
              <xsl:attribute name="src">
                <xsl:value-of select="$Link" />
              </xsl:attribute>
            </img>
          </a>
        </div>

      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>
