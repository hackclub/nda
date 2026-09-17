require "digest"

class NdaDocument
  VERSION = "2026-09-17"
  LEGACY_VERSION = "2025-04-01"
  TITLE = "MUTUAL NON-DISCLOSURE AGREEMENT"
  FOOTER = "Last revised 2026-09-17"
  LEGACY_FOOTER = "Last revised 2025-04-01"

  def self.para(text) = [ :p, text.squish ]
  def self.clause(text) = [ :clause, text.squish ]
  def self.subhead(text) = [ :subhead, text.squish ]

  LEGACY_INTRODUCTION = [
    para(<<~TEXT),
      This Mutual Non-Disclosure Agreement (the “Agreement”) is entered into by and between the Hack Foundation
      (“Hack Club” or “Organization”) with an address of 15 Falls Road, Shelburne, VT 05482 and Recipient. Hack
      Club and Recipient are sometimes referred to individually herein as a “Party” or collectively as the “Parties”.
    TEXT
    para("If Recipient is under the age of 18, this Agreement must also be co-signed by Co-signer.")
  ].freeze

  SIGNER_CONTEXT = [
    para(<<~TEXT),
      If you've been asked to sign this it means you're likely going to be granted access to systems or information
      that contain confidential or sensitive data.
    TEXT
    para(<<~TEXT),
      Part of being a volunteer at Hack Club means protecting that information. By signing this agreement, you
      acknowledge that you are serving as a volunteer or have been contracted / employed by Hack Club, agree to
      keep confidential information secure, and agree not to access, use, or disclose it except as necessary to support
      your authorized activities with Hack Club.
    TEXT
    para(<<~TEXT)
      This agreement does not create an employment or independent contractor relationship with The Hack Foundation
      or Hack Club.
    TEXT
  ].freeze

  INTRODUCTION = [
    *LEGACY_INTRODUCTION,
    *SIGNER_CONTEXT,
    para(<<~TEXT)
      Due to their employment and/or ongoing business relationship, which will necessarily involve the exchange of
      certain information deemed confidential, and in consideration of the foregoing and the mutual covenants and
      agreements herein set forth, the Parties hereby agree as follows:
    TEXT
  ].freeze

  SECTIONS = [
    [ "1. Confidential Information Defined", [
      para(<<~TEXT),
        All information (whether written or oral) furnished or disclosed in connection with the Discussions (whether
        before or after the date hereof) by the Disclosing Party or its directors, officers, employees, affiliates,
        representatives (including, without limitation, financial advisors, attorneys, accountants and agents, collectively,
        “Representatives”), including, but not limited to, trade secrets, business plans and projections, vendor lists,
        marketing information, employee lists and other human resources or personnel information, financial
        statements, and all analyses, compilations, forecasts, studies or other documents prepared by the Receiving
        Party or its Representatives in connection with the Receiving Party’s or its Representatives’ review of, or the
        Receiving Party’s interest in, the Discussions which contain or reflect any such information is hereinafter
        referred to as the “Confidential Information.”
      TEXT
      para("The term Confidential Information does not, however, include information which:"),
      clause(<<~TEXT),
        (a) is or becomes publicly available other than as a result of a disclosure by the Receiving Party or its
        Representatives;
      TEXT
      clause(<<~TEXT),
        (b) is or was independently developed by the Receiving Party without any use, aid or application of any
        of the Disclosing Party’s Confidential Information; or
      TEXT
      clause(<<~TEXT)
        (c) is or becomes available to, or was already known by, the Receiving Party on a non-confidential
        basis from a source (other than the Disclosing Party or its Representatives) which is not prohibited from
        disclosing such Confidential Information to the Receiving Party by a legal, contractual or fiduciary
        obligation to the Disclosing Party.
      TEXT
    ] ],
    [ "2. Effective Date", [
      para(<<~TEXT)
        The obligations of the Receiving Party hereunder shall be effective from the date the Receiving Party first
        receives the Confidential Information, and shall continue indefinitely unless, as to particular specified
        information, it is sooner terminated by the Disclosing Party. The obligations and liabilities of the Receiving Party
        contained herein shall survive the return of any of the Confidential Information and/or any discontinuance of
        any business relationships or agreements between the Disclosing Party and the Receiving Party or termination
        of this Agreement. Further, the obligation not to disclose shall not be affected by bankruptcy, receivership,
        assignment, attachment or seizure procedures, whether initiated by or against a Party, nor by the rejection of
        any contract between the Disclosing Party and the Receiving Party, by a trustee of a party in bankruptcy, or by
        a party as a debtor-in-possession or the equivalent of any of the foregoing under local law.
      TEXT
    ] ],
    [ "3. Keep Confidential", [
      para(<<~TEXT),
        Each Party and its Representatives will keep the Confidential Information confidential and will not (except as
        required by applicable law, regulation or legal process, and only after compliance with Section 6 below),
        without the Disclosing Party’s prior written consent, disclose any Confidential Information other than in
        connection with the Discussions; provided, however, that the Receiving Party may reveal the Confidential
        Information to its Representatives:
      TEXT
      clause("(a) who need to know the Confidential Information for the purpose of the Discussions;"),
      clause(<<~TEXT),
        (b) who are informed by the Receiving Party of the confidential nature of the Confidential Information;
        and
      TEXT
      clause("(c) who agree to act in accordance with the terms of this Agreement."),
      para(<<~TEXT)
        The Receiving Party will cause its Representatives to observe the terms of this Agreement, and the Receiving
        Party will be responsible for any breach of this Agreement by its Representatives.
      TEXT
    ] ],
    [ "4. Permitted Purpose", [
      para(<<~TEXT)
        The Receiving Party agrees that the Confidential Information will not be used by the Receiving Party or its
        Representatives for any purpose other than the Discussions and, if the Parties so choose, for the permitted
        purposes under any subsequent contracts between the Parties which are mutually executed by the Parties.
        The Receiving Party and its Representatives will not (except as required by applicable law, regulation or legal
        process, and only after compliance with Section 6 below), without the Disclosing Party’s prior written consent,
        disclose to any person the fact that the Confidential Information exists or has been made available, that the
        Receiving Party or the Disclosing Party is, was or has been involved in the Discussions, or any term, condition
        or other fact relating to the Discussions, including, without limitation, the status thereof.
      TEXT
    ] ],
    [ "5. Restrictions on Use", [
      para(<<~TEXT),
        The Receiving Party shall not, without the Disclosing Party’s prior written consent, directly or indirectly: (a) sell,
        license, provide access to, or disclose the Disclosing Party’s Confidential Information or any information
        derived therefrom to any third parties, including, but not limited to, any affiliated entity; (b) reproduce or make
        any use whatsoever at any time of the Confidential Information except as may be reasonably required for
        performing the Authorized Use(s) described in Section 4 above; (c) alter, modify, decompile, disassemble, or
        reverse engineer any such Confidential Information; and (d) register, attempt to register, or otherwise secure or
        attempt to secure any copyrights, trademarks, patents, or other intellectual property rights or protections in the
        Confidential Information anywhere in the world.
      TEXT
      subhead("(A) Reasonable Care"),
      para(<<~TEXT)
        The Receiving Party shall protect the Disclosing Party’s Confidential Information by
        using at least the same degree of care as the Receiving Party uses to protect its own
        Confidential Information of a like nature, but no less than reasonable care, to prevent the
        unauthorized use, disclosure or publication of the Confidential Information.
      TEXT
    ] ],
    [ "6. Disclosure Required by Law", [
      para(<<~TEXT)
        In the event that the Receiving Party or its Representatives are requested pursuant to, or required by,
        applicable law, regulation or legal process to disclose any of the Confidential Information, unless the Receiving
        Party, in the opinion of counsel, is legally prohibited from so doing, the Receiving Party will notify the Disclosing
        Party promptly so that the Disclosing Party may seek a protective order or other appropriate remedy. In the
        event that no such protective order or other remedy is obtained, the Receiving Party will furnish only that
        portion of the Confidential Information which the Receiving Party is advised by counsel is legally required and
        will exercise all reasonable efforts to obtain reliable assurance that confidential treatment will be accorded the
        Confidential Information.
      TEXT
    ] ],
    # Source called this section "Section 9" in its own retention proviso.
    [ "7. Destruction or Return of the Confidential Information", [
      para(<<~TEXT),
        If either Party determines not to proceed with the Discussions, such Party will promptly inform the other of that
        decision and, at any time upon the request of the Disclosing Party or its Representatives, the Receiving Party
        will, within five (5) days of receipt of such notification, either:
      TEXT
      clause("(a) destroy all copies containing any Confidential Information; or"),
      clause(<<~TEXT),
        (b) return to the Disclosing Party all copies of the Confidential Information in its possession or in the
        possession of its Representatives, whether in written form, electronically stored or otherwise provided
        by the Disclosing Party.
      TEXT
      para(<<~TEXT),
        If so requested by the Disclosing Party, the Receiving Party shall deliver a certificate executed by one of its
        duly authorized officers confirming compliance with the return or destruction obligation. Temporarily retaining
        backup copies of the Confidential Information on the Receiving Party’s server or other backup technology in
        accordance with the Receiving Party’s standard document retention policy (the “Retention Policy”) shall not
        constitute a violation of this Section 7 provided that:
      TEXT
      clause("(i) such Confidential Information is no longer used by the Receiving Party or its Representatives;"),
      clause(<<~TEXT),
        (ii) the Retention Policy only requires backup copies to be stored for a reasonable amount of time after
        file deletion; and
      TEXT
      clause(<<~TEXT)
        (iii) that the Confidential Information is timely deleted or destroyed in accordance with the Retention
        Policy.
      TEXT
    ] ],
    [ "8. No Representations or Warranties", [
      para(<<~TEXT)
        Each Party acknowledges that neither Party, nor its Representatives, nor any of its or their respective officers,
        directors, employees, agents or controlling persons, makes any express or implied representation or warranty
        as to the accuracy or completeness of the Confidential Information, and each Party agrees that no such person
        will have any liability relating to the Confidential Information for any errors contained therein or omissions
        therefrom. Each Party further agrees that such Party is not entitled to rely on the accuracy and completeness
        of the Confidential Information and that each Party will be entitled to rely solely on such representations and
        warranties as may be included in any definitive agreement with respect to the Discussions, subject to such
        limitations and restrictions as may be contained therein.
      TEXT
    ] ],
    [ "9. No License", [
      para(<<~TEXT)
        Nothing contained herein shall be construed as granting or conferring any rights by license or otherwise in any
        of the Confidential Information. It is understood and agreed that the disclosure of the Confidential Information
        shall not be construed as evidencing any intent by the Disclosing Party to purchase any products or services
        from the Receiving Party except pursuant to a mutually executed contract between the Parties. The Receiving
        Party agrees not to use any of the Confidential Information as a basis upon which to develop or have a third
        party develop a competing or similar product or service, whether the Disclosing Party has already produced
        and/or offers such a product or service or has provided Confidential Information related to prospective or
        unannounced products, designs and/or services.
      TEXT
    ] ],
    [ "10. Notification of Disclosure", [
      para(<<~TEXT)
        The Receiving Party must notify the Disclosing Party immediately of any disclosures of the Confidential
        Information, subject to the provisions of Section 6 hereof. The Receiving Party shall fully cooperate with all
        requests of the Disclosing Party in connection with recovering and limiting the dissemination of the Confidential
        Information.
      TEXT
    ] ],
    [ "11. Injunctive Relief and Costs", [
      para(<<~TEXT)
        Each Party hereby covenants and agrees that it will comply with and carry out all of the provisions of this
        Agreement applicable to it. Each Party also acknowledges and agrees that the disclosure or use of the
        Confidential Information in violation of the terms of this Agreement would cause the other Party irreparable
        harm. The Parties further acknowledge and agree that, in the event of a breach or threatened breach of this
        Agreement, a determination of actual damages incurred by a Disclosing Party would be extremely difficult to
        determine. Consequently, in the event of such a breach or threatened breach, the Disclosing Party will be
        entitled, in addition to any and all other remedies available at law, to appropriate equitable relief, including but
        not limited to, an injunction and an order of specific performance to prevent the disclosure and use of the
        Confidential Information in violation of the terms hereof. In the event of litigation relating to this Agreement, if a
        court of competent jurisdiction determines that either Party or its Representatives have breached this
        Agreement, the breaching Party will reimburse the other Party for its costs and expenses (including, without
        limitation, legal fees and expenses) incurred in connection with all such litigation.
      TEXT
    ] ],
    [ "12. No Waiver", [
      para(<<~TEXT)
        Each Party agrees that no failure or delay by the other Party in exercising any right, power or privilege
        hereunder will operate as a waiver thereof, nor will any single or partial exercise thereof preclude any other or
        further exercise thereof or the exercise of any right, power or privilege hereunder.
      TEXT
    ] ],
    [ "13. Governing Law; Forum Selection", [
      para(<<~TEXT)
        This Agreement will be governed by and construed in accordance with the laws of the State of Vermont,
        without giving effect to principles of conflict of laws that would require the application of any other law. All
        questions or controversies arising out of or in any way relating to this Agreement and any dispute relating in
        any way to the existence, modification or termination of the commercial relations of the Parties shall be
        submitted to the United States District Court for the District of Vermont, or, in the event that District Court is
        without subject matter jurisdiction, to the courts of the State of Vermont having subject matter jurisdiction, and
        the Parties submit themselves to the personal jurisdiction of such District Court or Vermont State Court, as the
        case may be.
      TEXT
    ] ],
    [ "14. No Assignment", [
      para(<<~TEXT)
        Neither Party shall transfer or assign any rights or delegate any obligations herein, in whole or in part, whether
        voluntarily or by operation of law, without the prior written consent of the other Party, which shall not be
        unreasonably withheld. Subject to the preceding sentence, this Agreement shall be binding upon and inure to
        the benefit of the Parties hereto and, subject to the other provisions of this Agreement, on their respective
        successors and assigns.
      TEXT
    ] ],
    [ "15. No Third-Party Beneficiaries", [
      para(<<~TEXT)
        Nothing expressed or referred to in this Agreement will be construed to give any person other than the Parties
        to this Agreement any legal or equitable right, remedy or claim under or with respect to this Agreement or any
        provision of this Agreement, except such rights as shall inure to a successor or permitted assignee pursuant to
        this Section.
      TEXT
    ] ],
    [ "16. Severability", [
      para(<<~TEXT)
        If any term, covenant or condition of this Agreement or the application thereof to any person or circumstance
        shall, at any time or to any extent, be invalid or unenforceable, the remainder of this Agreement, or the
        application of such term, covenant or condition to persons or circumstances other than those as to which it is
        held invalid or unenforceable, shall not be affected thereby and each term, covenant or condition of this
        Agreement shall be valid and enforceable to the fullest extent permitted by law.
      TEXT
    ] ],
    [ "17. Entire Agreement; Amendment", [
      para(<<~TEXT)
        This Agreement, including any exhibits, schedules and attachments, supersedes all prior agreements, whether
        written or oral, between the Parties with respect to its subject matter, and there are no covenants, promises,
        agreements, conditions or understandings, written or oral, except as herein set forth. This Agreement may not
        be amended except by an instrument in writing executed by both Parties.
      TEXT
    ] ],
    [ "18. Counterparts", [
      para(<<~TEXT)
        This Agreement may be executed in two or more counterparts, each of which shall be deemed an original but
        all of which together shall constitute one and the same instrument. Each Party may execute this Agreement by
        digital or analog means and such e-signature shall be binding on the executing Party.
      TEXT
    ] ]
  ].freeze

  TEXT = ([ TITLE ] +
    INTRODUCTION.map(&:last) +
    SECTIONS.flat_map { |title, blocks| [ title ] + blocks.map(&:last) } +
    [ FOOTER ]).join("\n\n").freeze

  LEGACY_TEXT = ([ TITLE ] +
    LEGACY_INTRODUCTION.map(&:last) +
    [ INTRODUCTION.last.last ] +
    SECTIONS.flat_map { |title, blocks| [ title ] + blocks.map(&:last) } +
    [ LEGACY_FOOTER ]).join("\n\n").freeze

  def self.sha256 = Digest::SHA256.hexdigest(TEXT)
end
