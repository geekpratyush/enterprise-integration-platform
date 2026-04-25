<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs">
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
    <xsl:template match="/">
        <message>
            <block1><logicalTerminal><xsl:value-of select="//*[local-name()='Fr']//*[local-name()='BICFI']"/></logicalTerminal></block1>
            <block2 type="input"><receiverAddress><xsl:value-of select="//*[local-name()='To']//*[local-name()='BICFI']"/></receiverAddress></block2>
            <block4>
                <field><name>20</name><component number="1"><xsl:value-of select="//*[local-name()='MsgId']"/></component></field>
                <field><name>32A</name>
                    <component number="2"><xsl:value-of select="//*[local-name()='IntrBkSttlmAmt']/@Ccy"/></component>
                    <component number="3"><xsl:value-of select="translate(//*[local-name()='IntrBkSttlmAmt'], '.', ',')"/></component>
                </field>
                <field><name>50K</name>
                    <component number="2"><xsl:value-of select="//*[local-name()='Dbtr']/*[local-name()='Nm']"/></component>
                </field>
                <field><name>59</name>
                    <component number="2"><xsl:value-of select="//*[local-name()='Cdtr']/*[local-name()='Nm']"/></component>
                </field>
            </block4>
        </message>
    </xsl:template>
</xsl:stylesheet>
