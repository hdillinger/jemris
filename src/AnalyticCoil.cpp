/** @file AnalyticCoil.cpp
 *  @brief Implementation of AnalyticCoil
 *
 * Author: tstoecker
 * Date  : Jan 20, 2010
 */

/*
 *  JEMRIS Copyright (C) 2007-2010  Tony Stöcker, Kaveh Vahedipour
 *                                  Forschungszentrum Jülich, Germany
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */



#include "config.h"

#include "AnalyticCoil.h"


bool AnalyticCoil::Prepare (PrepareMode mode) {

    bool success = true;

    ATTRIBUTE("UseGrid"    , m_use_grid   );
    ATTRIBUTE("Sensitivity", m_sensitivity);

    Attribute* psens = GetAttribute("Sensitivity");
    psens->SetObservable(false);

    success   = Coil::Prepare(mode);

    if ( mode !=PREP_UPDATE  && !m_analytic) {
    	psens->SetObservable(true);
        string val=GetDOMattribute("Sensitivity");
        /* set the analytic formula for sensitivty evaluation */
        HIDDEN_ATTRIBUTE("posX", m_px  );
        Observe(psens,GetName(),"posX", mode == PREP_VERBOSE);
        stringstream sX; sX << "a" << m_obs_attribs.size();
        ReplaceString(val,"X",sX.str());
        HIDDEN_ATTRIBUTE("posY", m_py  );
        Observe(psens,GetName(),"posY", mode == PREP_VERBOSE);
        stringstream sY; sY << "a" << m_obs_attribs.size();
        ReplaceString(val,"Y",sY.str());
        HIDDEN_ATTRIBUTE("posZ", m_pz  );
        Observe(psens,GetName(),"posZ", mode == PREP_VERBOSE);
        stringstream sZ; sZ << "a" << m_obs_attribs.size();
        ReplaceString(val,"Z",sZ.str());
        m_analytic=psens->SetMember(val, m_obs_attribs, mode == PREP_VERBOSE);
    }

	//test GiNaC evaluation: calculate the sensitivities on a grid
	if (m_analytic) {
		try {
			bool b = m_use_grid;
			m_use_grid = false;
			DumpSensMap("");
			m_use_grid = b;
		} catch (exception &p) {
			if (mode == PREP_VERBOSE) {
				cout	<< "Warning in " << GetName() << ": attribute Sensitivity"
						<< " can not evaluate its GiNaC expression"
						<< " Reason: " << p.what() << endl;
			}
		}


	}

    return success;

}

/*******************************************************************/
double AnalyticCoil::GetSensitivity(double* position) {

	if (!m_analytic)  return 0.0;

    if (m_use_grid) {
		if (round(position[ZC]/m_space_res[ZC])+m_matrx_res[ZC]/2 > 0 && round(position[ZC]/m_space_res[ZC])+m_matrx_res[ZC]/2 < m_matrx_res[ZC]) {
			double s = m_sens_map [(int)round(position[ZC]/m_space_res[ZC])+m_matrx_res[ZC]/2]
							  [(int)round(position[YC]/m_space_res[YC])+m_matrx_res[YC]/2]
							  [(int)round(position[XC]/m_space_res[XC])+m_matrx_res[XC]/2];
			//cout << "INTERP!! " << "S(" << position[XC] << "," << position[YC] << "," << position[ZC] << ") = " << s << endl;
			return s;
		} else return 0.0;

    } else {

    	m_px = position[XC]-m_position[XC];
		m_py = position[YC]-m_position[YC];
		m_pz = position[ZC]-m_position[ZC];

		GetAttribute("Sensitivity")->EvalExpression();

		//cout << "ANALYT!! " << "S(" << position[XC] << "," << position[YC] << "," << position[ZC] << ") = " << m_sensitivity << endl;

		return m_sensitivity;
    }

}


