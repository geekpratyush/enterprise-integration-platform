<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs">
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
    <xsl:param name="Target_Namespace" select="'urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10'"/>
    <xsl:param name="BAH_Namespace" select="'urn:iso:std:iso:20022:tech:xsd:head.001.001.02'"/>
    <xsl:variable name="dt" select="format-dateTime(current-dateTime(), '[Y0001]-[M01]-[D01]T[H01]:[m01]:[s01]Z')"/>

    <xsl:template name="get"><xsl:param name="t"/><xsl:param name="c" select="'1'"/><xsl:variable name="g" select="//field[name=$t]/component[@number=$c]"/><xsl:variable name="f" select="//*[local-name()=concat('tag',$t) or local-name()=concat('f',$t) or local-name()=concat('Field',$t)]"/><xsl:value-of select="($g[normalize-space()], $f/*[local-name()=concat('component',$c)], $f[not(*)])[1]"/></xsl:template>

    <xsl:variable name="f20"><xsl:call-template name="get"><xsl:with-param name="t" select="'20'"/></xsl:call-template></xsl:variable>

    <xsl:template match="/">
        <xsl:element name="BizMsgEnv" namespace="{$BAH_Namespace}">
            <xsl:element name="AppHdr" namespace="{$BAH_Namespace}">
                <xsl:element name="Fr" namespace="{$BAH_Namespace}"><xsl:element name="FIId" namespace="{$BAH_Namespace}"><xsl:element name="FinInstnId" namespace="{$BAH_Namespace}"><xsl:element name="BICFI" namespace="{$BAH_Namespace}"><xsl:value-of select="(//block1/logicalTerminal, //*[local-name()='sender'], 'NOTPROVIDED')[1]"/></xsl:element></xsl:element></xsl:element></xsl:element>
                <xsl:element name="To" namespace="{$BAH_Namespace}"><xsl:element name="FIId" namespace="{$BAH_Namespace}"><xsl:element name="FinInstnId" namespace="{$BAH_Namespace}"><xsl:element name="BICFI" namespace="{$BAH_Namespace}"><xsl:value-of select="(//block2/receiverAddress, //*[local-name()='receiver'], 'NOTPROVIDED')[1]"/></xsl:element></xsl:element></xsl:element></xsl:element>
                <xsl:element name="BizMsgIdr" namespace="{$BAH_Namespace}"><xsl:value-of select="$f20"/></xsl:element>
                <xsl:element name="MsgDefIdr" namespace="{$BAH_Namespace}">pacs.008.001.10</xsl:element>
            </xsl:element>
            <xsl:element name="Document" namespace="{$Target_Namespace}">
                <xsl:element name="FIToFICstmrCdtTrf" namespace="{$Target_Namespace}">
                    <xsl:element name="GrpHdr" namespace="{$Target_Namespace}">
                        <xsl:element name="MsgId" namespace="{$Target_Namespace}"><xsl:value-of select="$f20"/></xsl:element>
                        <xsl:element name="CreDtTm" namespace="{$Target_Namespace}"><xsl:value-of select="$dt"/></xsl:element>
                        <xsl:element name="NbOfTxs" namespace="{$Target_Namespace}">1</xsl:element>
                        <xsl:element name="SttlmInf" namespace="{$Target_Namespace}"><xsl:element name="SttlmMtd" namespace="{$Target_Namespace}">INDA</xsl:element></xsl:element>
                    </xsl:element>
                    <xsl:element name="CdtTrfTxInf" namespace="{$Target_Namespace}">
                        <xsl:element name="PmtId" namespace="{$Target_Namespace}"><xsl:element name="InstrId" namespace="{$Target_Namespace}"><xsl:value-of select="$f20"/></xsl:element><xsl:element name="EndToEndId" namespace="{$Target_Namespace}"><xsl:variable name="v"><xsl:call-template name="get"><xsl:with-param name="t" select="'21'"/></xsl:call-template></xsl:variable><xsl:value-of select="($v[normalize-space()], 'NOTPROVIDED')[1]"/></xsl:element></xsl:element>
                        <xsl:element name="IntrBkSttlmAmt" namespace="{$Target_Namespace}">
                            <xsl:attribute name="Ccy"><xsl:call-template name="get"><xsl:with-param name="t" select="'32A'"/><xsl:with-param name="c" select="'2'"/></xsl:call-template></xsl:attribute>
                            <xsl:variable name="a"><xsl:call-template name="get"><xsl:with-param name="t" select="'32A'"/><xsl:with-param name="c" select="'3'"/></xsl:call-template></xsl:variable><xsl:value-of select="translate($a, ',', '.')"/>
                        </xsl:element>

                        <xsl:element name="Dbtr" namespace="{$Target_Namespace}"><xsl:call-template name="P"><xsl:with-param name="t" select="'50'"/></xsl:call-template></xsl:element>
                        <xsl:element name="Cdtr" namespace="{$Target_Namespace}"><xsl:call-template name="P"><xsl:with-param name="t" select="'59'"/></xsl:call-template></xsl:element>
                    </xsl:element>
                </xsl:element>
            </xsl:element>
        </xsl:element>
    </xsl:template>

    <xsl:template name="P"><xsl:param name="t"/><xsl:variable name="f" select="//field[starts-with(name,$t)]"/>
        <xsl:element name="Nm" namespace="{$Target_Namespace}"><xsl:value-of select="($f/component[@number='2'], 'NOTPROVIDED')[1]"/></xsl:element>
        <xsl:element name="PstlAdr" namespace="{$Target_Namespace}">
            <xsl:variable name="last" select="count($f/component[@number &gt; 2]) + 2"/>
            <xsl:variable name="ctry" select="$f/component[@number = $last]"/>
            <xsl:if test="string-length($ctry) = 2"><xsl:element name="Ctry" namespace="{$Target_Namespace}"><xsl:value-of select="$ctry"/></xsl:element></xsl:if>
            <xsl:if test="$last &gt; 3"><xsl:element name="TwnNm" namespace="{$Target_Namespace}"><xsl:value-of select="$f/component[@number = $last - 1]"/></xsl:element></xsl:if>
            <xsl:for-each select="$f/component[@number &gt; 2 and @number &lt; $last - 1]">
                <xsl:element name="AdrLine" namespace="{$Target_Namespace}"><xsl:value-of select="."/></xsl:element>
            </xsl:for-each>
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
