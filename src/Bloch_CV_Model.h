/** @file Bloch_CV_Model.h
 *  @brief Implementation of JEMRIS Blo_CV_Model.h
 */

/*
 *  JEMRIS Copyright (C) 2007-2009  Tony Stöcker, Kaveh Vahedipour
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

#ifndef BLOCH_CV_MODEL_H_
#define BLOCH_CV_MODEL_H_

#include "Model.h"

//CVODE2.5 includes:
#include "cvode/cvode.h"
#include "nvector/nvector_serial.h"


#define NEQ   3                   // number of equations
#define RTOL  1e-4                // scalar relative tolerance
#define ATOL1 1e-6                // vector absolute tolerance components
#define ATOL2 1e-6
#define ATOL3 1e-6
#define BEPS  1e-10

//! Structure keeping the vectors for cvode
struct nvec {
    N_Vector y;      /**< CVODE vector */
    N_Vector abstol; /**< CVODE vector */
};

/**
 * @brief Numerical solving of Bloch equations
 * As an application of the CVODE solver
 * by Lawrence Livermore National Laboratory - Livermore, CA
 * http://www.llnl.gov/CASC/sundials
 */

//! MR model solver using CVODE
class Bloch_CV_Model : public Model {

 public:

    /**
     * @brief Default destructor
     */
    virtual ~Bloch_CV_Model      () {
    	CVodeFree(&m_cvode_mem);
    };

    /**
     * @brief Constructor
     */
    Bloch_CV_Model               ();


 protected:

    /**
     * @brief Initialise solver
     *
     * Inistalise N_Vector and attach it to my world
     */
    virtual void InitSolver      ();

    /**
     * @brief Free solver
     *
     * Release the N_Vector
     */
    virtual void FreeSolver      ();

    /**
     * @brief Solve
     *
     * Numerical integration of the Bloch equations for a given atomic sequence
     *
     * @param dTimeShift  Starting time of this atom with respekt to the start of
     *                    the whole sequence
     * @param lIndexShift More elaborate description here please
     * @param atom        The simulated atomic sequence
     * @param lSpin       The index number od the spin which is being simulated
     * @param pfout       The file output stream used for intermediate result output
     * @param iStep       More elaborate description here please
     */
    void         Solve           (double& dTimeShift, long& lIndexShift, AtomicSequence* atom, long& lSpin, ofstream* pfout, int iStep);

    /**
     * @brief Summery output
     *
     * More elaborate description here please
     */
    void         PrintFinalStats ();


    /**
     *  see Model::Calculate()
     */
    virtual void Calculate       (double next_tStop);

 private:

    // CVODE related
    void*  m_cvode_mem;
    double m_tpoint;
 //   long   m_iopt[NEQ];
 //   cvreal m_ropt[NEQ], m_reltol;
    double m_reltol;

};

#endif /*BLOCH_CV_MODEL_H_*/