<!--
  - Copyright (c) 2016 Vojtech Horky
  - All rights reserved.
  -
  - Redistribution and use in source and binary forms, with or without
  - modification, are permitted provided that the following conditions
  - are met:
  -
  - - Redistributions of source code must retain the above copyright
  -   notice, this list of conditions and the following disclaimer.
  - - Redistributions in binary form must reproduce the above copyright
  -   notice, this list of conditions and the following disclaimer in the
  -   documentation and/or other materials provided with the distribution.
  - - The name of the author may not be used to endorse or promote products
  -   derived from this software without specific prior written permission.
  -
  - THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
  - IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
  - OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
  - IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
  - INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
  - NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  - DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  - THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  - (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
  - THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
  -->
<xsl:stylesheet version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml" indent="yes"/>

<xsl:param name="SIZE" select="'4'" />

<xsl:template match="/builds">
<xsl:variable name="MAX_POSITION" select="number($SIZE)" />
<builds>
    <xsl:for-each select="build">
        <xsl:sort select="@date" order="descending" />
        <xsl:if test="position() &lt;= $MAX_POSITION">
            <xsl:copy-of select="." />
        </xsl:if>
    </xsl:for-each>
</builds>
</xsl:template>

</xsl:stylesheet>
